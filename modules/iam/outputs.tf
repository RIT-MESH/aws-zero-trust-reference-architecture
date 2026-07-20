output "break_glass_role_arn" {
  description = "ARN of the break-glass role (no permanent credential; MFA-gated)."
  value       = aws_iam_role.break_glass.arn
}

output "workload_permission_boundary_arn" {
  description = "ARN of the workload permission boundary policy."
  value       = aws_iam_policy.workload_permission_boundary.arn
}

output "example_scp_json" {
  description = "Example Service Control Policy JSON (apply in your organization manually)."
  value       = data.aws_iam_policy_document.example_scp.json
}
