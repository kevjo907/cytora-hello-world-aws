# ---------------------------------------------------------------------------
# HTTP API
#
# HTTP APIs (v2) rather than REST APIs (v1): roughly 70% cheaper per million
# requests, lower latency, and native support for the leaner 2.0 payload
# format. A REST API would only be worth it for features we do not need here,
# such as usage plans, request validation, or direct WAF association.
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  description   = "HTTP front door for the ${var.lambda_function_name} function."
  protocol_type = "HTTP"

  dynamic "cors_configuration" {
    for_each = length(var.cors_allow_origins) > 0 ? [1] : []

    content {
      allow_origins = var.cors_allow_origins
      allow_methods = ["GET", "OPTIONS"]
      allow_headers = ["content-type"]
      max_age       = 300
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Access logging
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Lambda proxy integration
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.this.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.lambda_invoke_arn

  # AWS_PROXY integrations always speak POST to Lambda, whatever the client
  # method was; the original method arrives inside the event.
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "this" {
  for_each = toset(var.routes)

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# ---------------------------------------------------------------------------
# Stage
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn

    # JSON rather than CLF so CloudWatch Logs Insights can query fields
    # directly without a regex parse.
    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      path             = "$context.path"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      responseLatency  = "$context.responseLatency"
      sourceIp         = "$context.identity.sourceIp"
      userAgent        = "$context.identity.userAgent"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  # A public unauthenticated endpoint needs a ceiling, otherwise a burst of
  # traffic turns straight into a Lambda bill.
  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Invoke permission
#
# Scoped to this API's execution ARN, so no other API can call the function.
# ---------------------------------------------------------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
