variable "name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "source_dir" {
  description = "Directory containing the Lambda source to package."
  type        = string
}

variable "handler" {
  description = "Entrypoint in <module>.<function> form."
  type        = string
  default     = "handler.handler"
}

variable "runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "python3.12"
}

variable "architecture" {
  description = "Instruction set. arm64 (Graviton) is ~20% cheaper than x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be either arm64 or x86_64."
  }
}

variable "memory_size" {
  description = "Memory in MB. Lambda scales CPU with memory, so this also sets CPU."
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Function timeout in seconds. Kept below the API Gateway 30s limit."
  type        = number
  default     = 10

  validation {
    condition     = var.timeout > 0 && var.timeout <= 29
    error_message = "timeout must be 1-29s; API Gateway HTTP APIs cut off at 30s."
  }
}

variable "environment_variables" {
  description = "Environment variables injected into the function."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention. 0 means retain forever."
  type        = number
  default     = 14
}

variable "tracing_mode" {
  description = "X-Ray tracing mode: Active or PassThrough."
  type        = string
  default     = "Active"
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
