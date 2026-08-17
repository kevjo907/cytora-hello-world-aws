output "api_id" {
  description = "Identifier of the HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Base URL of the deployed API."
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "execution_arn" {
  description = "Execution ARN of the API, used for invoke permissions."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "access_log_group_name" {
  description = "CloudWatch log group receiving API access logs."
  value       = aws_cloudwatch_log_group.access.name
}
