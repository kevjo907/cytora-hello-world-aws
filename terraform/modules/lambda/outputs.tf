output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN used by API Gateway to invoke the function."
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "ARN of the execution role."
  value       = aws_iam_role.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group receiving the function's logs."
  value       = aws_cloudwatch_log_group.lambda.name
}
