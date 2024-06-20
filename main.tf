# Random suffix for resource naming
resource "random_string" "this" {
  lower   = true
  upper   = false
  special = false
  numeric = false
  length  = 5
}

# VPC with Tagging in Place
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name"      = "EventBridge Tagging Demo"
    "RunLambda" = "true"
  }

  depends_on = [
    aws_cloudwatch_event_rule.this
  ]
}

# Assume Role Policy
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Lambda IAM Policy for Lambda Function
resource "aws_iam_policy" "this" {
  name = "process-vpc-tag-change-policy-${random_string.this.result}"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : "arn:aws:logs:eu-west-1:*:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : [
            "arn:aws:logs:eu-west-1:*:log-group:/aws/lambda/process-vpc-tag-change*:*"
          ]
        }
      ]
    }
  )
}

# IAM Role for Lambda Function
resource "aws_iam_role" "this" {
  name                = "process-vpc-tag-change-role-${random_string.this.result}"
  assume_role_policy  = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [aws_iam_policy.this.arn]

}

# Archive of Python Lambda Function Code
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "lambda_function_payload.zip"
}

# Lambda Function for Processing the Tag Change
resource "aws_lambda_function" "this" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "process-vpc-tag-change-${random_string.this.result}"
  role             = aws_iam_role.this.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.12"
}

# AWS EventBridge Rule - EventBridge was formerly known as CloudWatch Events. The functionality is identical.
resource "aws_cloudwatch_event_rule" "this" {
  name        = "process-vpc-tag-change-${random_string.this.result}"
  description = "Capture VPC Tag Changes and Run Lambda on Specific Change"

  event_pattern = jsonencode(
    {
      "source" : ["aws.tag"],
      "detail" : {
        "resource-type" : ["vpc"],
        "changed-tag-keys" : ["RunLambda"]
      }
    }
  )
}

# Sets the Target for the EventBridge Rule to be the Lambda Function
resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = aws_lambda_function.this.function_name
  arn       = aws_lambda_function.this.arn
}

# Sets the permissions on the Lambda Function
resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}