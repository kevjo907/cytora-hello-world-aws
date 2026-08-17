variable "name" {
  description = "Name of the API."
  type        = string
}

variable "stage_name" {
  description = "Deployment stage. Use $default to serve from the API root path."
  type        = string
  default     = "$default"
}

variable "lambda_invoke_arn" {
  description = "invoke_arn of the Lambda function to integrate with."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function, used to scope the invoke permission."
  type        = string
}

variable "routes" {
  description = "Route keys to expose, e.g. [\"GET /\", \"GET /hello\"]."
  type        = list(string)
  default     = ["GET /", "GET /hello"]
}

variable "throttling_burst_limit" {
  description = "Burst request limit for the stage."
  type        = number
  default     = 100
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second for the stage."
  type        = number
  default     = 50
}

variable "cors_allow_origins" {
  description = "Origins allowed by CORS. Empty list disables CORS entirely."
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Retention for API Gateway access logs."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
