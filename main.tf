locals {
  name_prefix     = "${var.project_name}-cloudtrail-to-slack"
  lambda_zip_path = "${path.root}/builds/lambda_package.zip"
  common_tags = merge(var.tags, {
    Module  = "cloudtrail-to-slack"
    Project = var.project_name
  })
}

data "aws_caller_identity" "current" {}

# ─── CloudWatch Log Group ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_prefix}"
  retention_in_days = 30
  tags              = local.common_tags
}

# ─── IAM Role for Lambda ──────────────────────────────────────────────────────

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowLambdaToGetCloudTrailObjects"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.cloudtrail_logs_s3_bucket_name}/*"
      },
      {
        Sid      = "AllowLambdaToPushCloudWatchMetrics"
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# ─── Lambda Package Build ─────────────────────────────────────────────────────

resource "null_resource" "lambda_build" {
  triggers = {
    requirements_hash = filesha256("${path.module}/lambda/deploy_requirements.txt")
    source_hash       = sha256(join("", [for f in sort(fileset("${path.module}/lambda", "*.py")) : filesha256("${path.module}/lambda/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p "${path.root}/builds"
      TMP=$(mktemp -d)
      python3.10 -m pip install --no-compile --prefix= --target="$TMP" -r "${path.module}/lambda/deploy_requirements.txt" --quiet
      cp "${path.module}"/lambda/*.py "$TMP/"
      cd "$TMP" && zip -r "${abspath(path.root)}/builds/lambda_package.zip" . -x "*.pyc" -x "*/__pycache__/*" > /dev/null
      rm -rf "$TMP"
    EOT
  }
}

# ─── Lambda Function ──────────────────────────────────────────────────────────

resource "aws_lambda_function" "this" {
  function_name    = local.name_prefix
  role             = aws_iam_role.lambda.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.10"
  filename         = local.lambda_zip_path
  source_code_hash = null_resource.lambda_build.triggers["source_hash"]
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb

  environment {
    variables = {
      HOOK_URL                              = var.slack_webhook_url
      EVENTS_TO_TRACK                       = var.events_to_track
      IGNORE_RULES                          = var.ignore_rules
      RULES_SEPARATOR                       = var.rules_separator
      USE_DEFAULT_RULES                     = "false"
      RULES                                 = ""
      LOG_LEVEL                             = var.log_level
      PUSH_ACCESS_DENIED_CLOUDWATCH_METRICS = "true"
      RULE_EVALUATION_ERRORS_TO_SLACK       = "true"
      FUNCTION_NAME                         = local.name_prefix
      CONFIGURATION                         = "null"
      SNS_CONFIGURATION                     = "null"
      SLACK_APP_CONFIGURATION               = "null"
      DYNAMODB_TABLE_NAME                   = ""
      DYNAMODB_TIME_TO_LIVE                 = "900"
    }
  }

  depends_on = [
    null_resource.lambda_build,
    aws_cloudwatch_log_group.lambda,
  ]

  tags = local.common_tags
}

# ─── S3 Trigger → Lambda ──────────────────────────────────────────────────────

resource "aws_lambda_permission" "s3" {
  statement_id   = "AllowExecutionFromS3Bucket"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = "arn:aws:s3:::${var.cloudtrail_logs_s3_bucket_name}"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "cloudtrail" {
  bucket = var.cloudtrail_logs_s3_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".json.gz"
  }

  depends_on = [aws_lambda_permission.s3]
}
