output "api_endpoint" {
  description = "Base URL of the deployed API. Try: curl $(terraform output -raw api_endpoint)"
  value       = module.api.api_endpoint
}

output "hello_url" {
  description = "Full URL of the /hello route."
  value       = "${module.api.api_endpoint}hello"
}

output "lambda_function_name" {
  description = "Name of the deployed Lambda function."
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch log group for the Lambda function."
  value       = module.lambda.log_group_name
}

output "api_access_log_group" {
  description = "CloudWatch log group for API Gateway access logs."
  value       = module.api.access_log_group_name
}
