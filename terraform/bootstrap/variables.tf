variable "aws_region" {
  description = "AWS region for the state bucket and IAM resources."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project identifier; must match the root module's project_name."
  type        = string
  default     = "hello-world"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the deploy role, as owner/repo."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo form."
  }
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}
