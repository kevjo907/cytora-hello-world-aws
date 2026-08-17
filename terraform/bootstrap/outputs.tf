output "state_bucket" {
  description = "Set this as the TF_STATE_BUCKET repository variable in GitHub."
  value       = aws_s3_bucket.state.id
}

output "github_actions_role_arn" {
  description = "Set this as the AWS_ROLE_ARN repository variable in GitHub."
  value       = aws_iam_role.github_actions.arn
}

output "next_steps" {
  description = "Commands to wire the pipeline up."
  value       = <<-EOT
    gh variable set AWS_ROLE_ARN     --body "${aws_iam_role.github_actions.arn}"
    gh variable set TF_STATE_BUCKET  --body "${aws_s3_bucket.state.id}"
    gh variable set AWS_REGION       --body "${var.aws_region}"
  EOT
}
