locals {
  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Security groups. The ALB SG uses inline ingress (CIDR-based, no cross-SG
# reference) and a separate egress rule to the app SG. The app SG is bare and
# gets a separate ingress rule from the ALB SG. Keeping the two cross-referencing
# rules as separate aws_vpc_security_group_*_rule resources avoids a Terraform
# dependency cycle (ALB SG egress -> app SG, app SG ingress -> ALB SG).
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow 80/443 from allowed CIDRs to the public ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

# This SG is attached to ECS Fargate tasks by the ecs-app module and referenced by
# the RDS module; the cross-module attachment is not visible to static analysis.
resource "aws_security_group" "app" {
  # checkov:skip=CKV2_AWS_5: Attached to ECS Fargate tasks (ecs-app module) and referenced by the RDS module; cross-module attachment is not visible to checkov.
  name        = "${var.name_prefix}-app-sg"
  description = "Application tier SG; ingress only from the ALB SG (managed by edge module)"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-app-sg"
  })
}

# ALB egress only to the application tier SG (SG reference, not a broad CIDR).
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to application tier via SG reference"
  from_port                    = var.app_target_port
  to_port                      = var.app_target_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

# App ingress only from the ALB SG (SG reference). No inbound SSH/RDP anywhere.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from ALB SG only"
  from_port                    = var.app_target_port
  to_port                      = var.app_target_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# -----------------------------------------------------------------------------
# Target group for the application (ECS Fargate tasks)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "app" {
  name        = "${var.name_prefix}-app-tg"
  port        = var.app_target_port
  protocol    = var.app_target_protocol
  vpc_id      = var.vpc_id
  target_type = "ip" # ECS Fargate uses ip targets

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    protocol            = var.app_target_protocol
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-app-tg"
  })
}

# -----------------------------------------------------------------------------
# Internet-facing ALB in public subnets (no workload public IPs here)
# -----------------------------------------------------------------------------
resource "aws_lb" "this" {
  # checkov:skip=CKV_AWS_150: ALB deletion protection is configurable; enabled in the production example and intentionally disabled in the lab example for easy teardown. See docs/cost.md.
  # checkov:skip=CKV2_AWS_76: The attached WAF includes AWSManagedRulesKnownBadInputsRuleSet (Log4j/CVE-2021-44228) and AWSManagedRulesLinuxRuleSet managed rule groups; checkov cannot resolve the ALB->WAF association statically.
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection

  dynamic "access_logs" {
    for_each = var.access_log_bucket_arn != "" ? [1] : []
    content {
      bucket  = var.access_log_bucket_arn
      prefix  = var.access_log_prefix
      enabled = true
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# HTTPS listener: forward to the application target group.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-https-listener"
  })
}

# HTTP listener: redirect to HTTPS.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-http-redirect"
  })
}

# -----------------------------------------------------------------------------
# AWS WAF: managed rule groups (including Log4j/CVE mitigation), rate-based rule,
# and S3 logging. Attached to the ALB.
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "this" {
  # checkov:skip=CKV2_AWS_31: A WAF logging configuration (aws_wafv2_web_acl_logging_configuration) is created whenever WAF is enabled, which both examples do.
  count       = var.enable_waf ? 1 : 0
  name        = "${var.name_prefix}-waf"
  description = "Zero Trust WAF for the public ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_based_rule_threshold
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-common"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = var.enable_ip_reputation_rules ? [1] : []
    content {
      name     = "aws-managed-ip-reputation"
      priority = 30
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "ip-reputation"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.enable_ip_reputation_rules ? [1] : []
    content {
      name     = "aws-managed-anonymous-ip"
      priority = 40
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAnonymousIpList"
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "anonymous-ip"
        sampled_requests_enabled   = true
      }
    }
  }

  # Linux rule set includes Log4j/CVE-2021-44228 mitigations.
  rule {
    name     = "aws-managed-linux"
    priority = 50
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "linux-rule-set"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${var.name_prefix}-waf"
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-waf"
  })
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}

# WAF logging to the centralized S3 bucket. Enabled whenever the WAF is enabled;
# the access_log_bucket_arn variable must be set when enable_waf is true.
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count                   = var.enable_waf ? 1 : 0
  log_destination_configs = ["${var.access_log_bucket_arn}/${var.access_log_prefix}waf/"]
  resource_arn            = aws_wafv2_web_acl.this[0].arn

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}