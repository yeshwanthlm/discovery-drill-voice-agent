terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------- DynamoDB: session continuity storage ----------
# NOTE: changing the hash_key from trainee_name to trainee_email forces
# Terraform to destroy and recreate this table. Fine now (no real data
# yet) — flagging so it's not a surprise on a table that matters later.
resource "aws_dynamodb_table" "sessions" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "trainee_email"

  attribute {
    name = "trainee_email"
    type = "S"
  }

  tags = {
    Project = "ready-check"
  }
}

# ---------- SES: verified sender identity ----------
# NOTE: creating this resource triggers AWS to send a verification email.
# You still have to click the link in that email before sends will work —
# Terraform cannot click it for you.
resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

# ---------- IAM: Lambda execution role ----------
resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Basic Lambda logging permissions
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Scoped DynamoDB access — read/write only, only this table
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.function_name}-dynamodb-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem"
      ]
      Resource = aws_dynamodb_table.sessions.arn
    }]
  })
}

# SES send permission
resource "aws_iam_role_policy" "ses_access" {
  name = "${var.function_name}-ses-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}

# NOTE: ready-check-backend (the original combined Lambda) has been
# replaced by two dedicated functions below. It remains live in AWS
# but is no longer managed by Terraform.

# ==========================================================================
# get-session-history Lambda
# ==========================================================================

data "archive_file" "get_history_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/get_session_history/get_session_history_lambda.py"
  output_path = "${path.module}/build/get_session_history.zip"
}

resource "aws_lambda_function" "get_session_history" {
  function_name    = "ready-check-get-session-history"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "get_session_history_lambda.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.get_history_zip.output_path
  source_code_hash = data.archive_file.get_history_zip.output_base64sha256
  timeout          = 10
}

resource "aws_lambda_function_url" "get_session_history_url" {
  function_name      = aws_lambda_function.get_session_history.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
  }
}

resource "aws_lambda_permission" "allow_public_get_session_history_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.get_session_history.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# ==========================================================================
# log-debrief Lambda
# ==========================================================================

data "archive_file" "log_debrief_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/log_debrief/log_debrief_lambda.py"
  output_path = "${path.module}/build/log_debrief.zip"
}

resource "aws_lambda_function" "log_debrief" {
  function_name    = "ready-check-log-debrief"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "log_debrief_lambda.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.log_debrief_zip.output_path
  source_code_hash = data.archive_file.log_debrief_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      SENDER_EMAIL = var.sender_email
      NOTIFY_EMAIL = var.notify_email
    }
  }
}

resource "aws_lambda_function_url" "log_debrief_url" {
  function_name      = aws_lambda_function.log_debrief.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
  }
}

resource "aws_lambda_permission" "allow_public_log_debrief_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.log_debrief.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
