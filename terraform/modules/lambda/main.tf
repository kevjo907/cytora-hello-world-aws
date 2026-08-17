# ---------------------------------------------------------------------------
# Deployment package
#
# The handler has no third-party dependencies, so Terraform can zip the source
# directly. If dependencies were ever added, this is the seam where a build
# step (pip install -t / Lambda layer / container image) would slot in.
# ---------------------------------------------------------------------------

data "archive_file" "package" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.terraform-build/${var.name}.zip"
  excludes    = ["__pycache__", "*.pyc", "requirements.txt"]
}

# ---------------------------------------------------------------------------
# Logging
#
# Created explicitly rather than letting Lambda auto-create it. That gives us a
# retention policy (an auto-created group keeps logs forever, and pays for it)
# and lets the execution role skip logs:CreateLogGroup entirely.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Execution role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-execution-role"
  description        = "Execution role for the ${var.name} Lambda function."
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# Least privilege by hand instead of the AWSLambdaBasicExecutionRole managed
# policy, which grants logs:* across every log group in the account.
data "aws_iam_policy_document" "permissions" {
  statement {
    sid    = "WriteOwnLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  dynamic "statement" {
    for_each = var.tracing_mode == "Active" ? [1] : []

    content {
      sid    = "WriteXRayTraces"
      effect = "Allow"

      actions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
      ]

      # X-Ray's ingestion APIs are not resource-scoped; "*" is the only valid
      # value AWS accepts here.
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-execution-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

# ---------------------------------------------------------------------------
# Function
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = var.name
  description   = "Hello World HTTP handler fronted by API Gateway."
  role          = aws_iam_role.this.arn

  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256

  handler       = var.handler
  runtime       = var.runtime
  architectures = [var.architecture]
  memory_size   = var.memory_size
  timeout       = var.timeout

  environment {
    variables = var.environment_variables
  }

  tracing_config {
    mode = var.tracing_mode
  }

  tags = var.tags

  # The role policy must exist before the first invocation, and the log group
  # before the function writes to it.
  depends_on = [
    aws_iam_role_policy.this,
    aws_cloudwatch_log_group.lambda,
  ]
}
