provider "aws" {
  region = var.region
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_execution_policy" {
  name   = "LambdaExecutionPolicy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "SendSMS"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "nodejs22.x"
  timeout       = 30

  s3_bucket = "your-s3-bucket"
  s3_key    = "function.zip"
}

resource "aws_api_gateway_rest_api" "sms_lambda_api" {
  name = "SMSLambdaApi"
}

resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.sms_lambda_api.id
  parent_id   = aws_api_gateway_rest_api.sms_lambda_api.root_resource_id
  path_part   = "send-sms"
}

resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.sms_lambda_api.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.sms_lambda_api.id
  resource_id             = aws_api_gateway_resource.api_resource.id
  http_method             = aws_api_gateway_method.api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.sms_lambda_api.id
  depends_on  = [aws_api_gateway_integration.api_integration]
}

resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id = aws_api_gateway_rest_api.sms_lambda_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "stage"
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.sms_lambda_api.execution_arn}/*/POST/send-sms"
}

data "aws_caller_identity" "current" {}

variable "region" {
  default = "us-east-1" //Change as needed
}
