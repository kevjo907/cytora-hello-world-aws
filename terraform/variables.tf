variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Short project identifier; prefixes every resource name."
  type        = string
  default     = "hello-world"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens, 2-31 chars."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "greeting_message" {
  description = "Greeting returned in the response body."
  type        = string
  default     = "Hello, World!"
}

variable "log_level" {
  description = "Log level for the Lambda function."
  type        = string
  default     = "INFO"
}

variable "lambda_memory_size" {
  description = "Memory in MB allocated to the Lambda function."
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 14
}

variable "throttling_burst_limit" {
  description = "API Gateway burst request limit."
  type        = number
  default     = 100
}

variable "throttling_rate_limit" {
  description = "API Gateway steady-state requests per second."
  type        = number
  default     = 50
}

variable "additional_tags" {
  description = "Extra tags merged into the defaults on every resource."
  type        = map(string)
  default     = {}
}
