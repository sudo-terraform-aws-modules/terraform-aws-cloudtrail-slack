output "lambda_function_arn" {
  description = "ARN of the Lambda function that processes CloudTrail events and sends Slack alerts."
  value       = aws_lambda_function.this.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Lambda execution logs."
  value       = aws_cloudwatch_log_group.lambda.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role used by the Lambda function."
  value       = aws_iam_role.lambda.arn
}
