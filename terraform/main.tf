# ---------------------------------------------------------------------------
# Hello World: API Gateway HTTP API -> Lambda
#
#   client --HTTPS--> API Gateway (HTTP API, $default stage)
#                       |  AWS_PROXY, payload format 2.0
#                       v
#                     Lambda (Python 3.12, arm64)
#                       |
#                       v
#                     CloudWatch Logs + X-Ray
# ---------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "Cytora_accessment"
    },
    var.additional_tags,
  )
}

module "lambda" {
  source = "./modules/lambda"

  name       = "${local.name_prefix}-fn"
  source_dir = "${path.module}/../src/hello"

  memory_size        = var.lambda_memory_size
  log_retention_days = var.log_retention_days

  environment_variables = {
    GREETING_MESSAGE = var.greeting_message
    STAGE            = var.environment
    LOG_LEVEL        = var.log_level
  }

  tags = local.tags
}

module "api" {
  source = "./modules/api_gateway"

  name                 = "${local.name_prefix}-api"
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name

  routes                 = ["GET /", "GET /hello"]
  throttling_burst_limit = var.throttling_burst_limit
  throttling_rate_limit  = var.throttling_rate_limit
  log_retention_days     = var.log_retention_days

  tags = local.tags
}
