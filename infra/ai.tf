resource "aws_iam_role" "parser" {
  # no name: CloudFormation generated it, and the import keeps it
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "parser_logs" {
  role       = aws_iam_role.parser.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "parser_bedrock" {
  name = "call-bedrock"
  role = aws_iam_role.parser.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = "*" # narrowing it is a discussion question
    }]
  })
}

# No vpc_config: it needs no database, so it costs $0 when idle and reaches Bedrock over the internet.
resource "aws_lambda_function" "parser" {
  function_name = "${var.project_name}-agenda-parser"
  package_type  = "Image"
  image_uri     = var.image_uri
  role          = aws_iam_role.parser.arn
  timeout       = 30
  memory_size   = 512

  image_config {
    entry_point = ["python", "-m", "awslambdaric"]
    command     = ["app.ai.agenda_lambda.handler"]
  }

  environment {
    variables = {
      PARSER_MODEL      = var.parser_model
      BEDROCK_REGION    = var.bedrock_region
      COGNITO_AUTHORITY = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.main.id}"
      COGNITO_CLIENT_ID = aws_cognito_user_pool_client.web.id
    }
  }

  # New images are rolled out by the app pipeline (make deploy-ai), not by a Terraform run.
  lifecycle {
    ignore_changes = [image_uri]
  }
}

# Public URL, but the handler rejects any request without a valid Cognito ID token (401).
resource "aws_lambda_function_url" "parser" {
  function_name      = aws_lambda_function.parser.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = var.allowed_origins
    allow_methods = ["POST"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 600
  }
}

resource "aws_lambda_permission" "parser_url" {
  statement_id           = "spry-ai-UrlInvokeUrlPermission-rTmg7278bdLi"
  function_name          = aws_lambda_function.parser.function_name
  action                 = "lambda:InvokeFunctionUrl"
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "parser_invoke" {
  statement_id             = "spry-ai-UrlInvokePermission-SW3V2s6qOpC6"
  function_name            = aws_lambda_function.parser.function_name
  action                   = "lambda:InvokeFunction"
  principal                = "*"
  invoked_via_function_url = true
}

resource "aws_budgets_budget" "monthly" {
  count = var.budget_email == "" ? 0 : 1

  name         = "${var.project_name}-monthly-5usd"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = "5"
  limit_unit   = "USD"

  notification {
    notification_type          = "FORECASTED"
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    notification_type          = "ACTUAL"
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_email]
  }
}
