data "aws_region" "current" {}

locals {
  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Application tier egress: HTTPS to interface endpoints / internet via NAT.
# The app SG itself is created by the edge module to avoid a dependency cycle.
# -----------------------------------------------------------------------------
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = var.app_security_group_id
  description       = "HTTPS to interface endpoints / internet via NAT"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# CloudWatch log group for container stdout/stderr
# -----------------------------------------------------------------------------
# Operational container logs are short-lived; security-relevant logs (CloudTrail, flow logs) have longer retention.
resource "aws_cloudwatch_log_group" "app" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn != "" ? var.log_kms_key_arn : null

  tags = merge(local.common_tags, {
    Name = var.log_group_name
  })
}
# -----------------------------------------------------------------------------
# ECS cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-cluster"
  })
}

# -----------------------------------------------------------------------------
# Task execution role: pull images, write logs, decrypt secrets. Least privilege.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "exec_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name_prefix}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.exec_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "exec_ecr" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "exec_logs" {
  name = "logs"
  role = aws_iam_role.exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.app.arn}:*"
    }]
  })
}

# Decrypt Secrets Manager secrets used by the task (only if a KMS key is provided).
resource "aws_iam_role_policy" "exec_secrets" {
  count = var.secrets_kms_key_arn != "" ? 1 : 0
  name  = "secrets"
  role  = aws_iam_role.exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:*:secret:${var.name_prefix}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = var.secrets_kms_key_arn
      },
    ]
  })
}

# -----------------------------------------------------------------------------
# Task role: application runtime permissions. Deliberately minimal (deny by default).
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = local.common_tags
}

# Workload role has no permissions by default; grant only what the app needs.
resource "aws_iam_role_policy" "task_least_privilege" {
  name = "least-privilege-default-deny"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = ["*"]
      Resource = ["*"]
      Condition = {
        StringNotEqualsIfExists = {
          "aws:CalledVia" = ["ecs-tasks.amazonaws.com"]
        }
      }
    }]
  })
}

# -----------------------------------------------------------------------------
# Task definition
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      # Minimal health endpoint exposed at /health by the sample app.
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # Security headers emitted by the application. See docs/security-controls.md.
      dockerLabels = {
        "x-content-type-options"    = "nosniff"
        "x-frame-options"           = "DENY"
        "strict-transport-security" = "max-age=31536000; includeSubDomains"
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-app-td"
  })
}

# -----------------------------------------------------------------------------
# ECS service (Fargate) in private subnets, behind the ALB.
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "this" {
  name             = "${var.name_prefix}-app-service"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false # No public IPs on workloads
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-app-service"
  })

  depends_on = [aws_iam_role_policy.exec_logs]
}

# -----------------------------------------------------------------------------
# Autoscaling (target tracking on average CPU)
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_target" "app" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name_prefix}-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}