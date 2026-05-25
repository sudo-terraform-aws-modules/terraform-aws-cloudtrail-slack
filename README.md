# terraform-cloudtrail-to-slack

<img src="https://github.com/user-attachments/assets/a09f3eff-3e08-4a3c-b490-71117a40080b" width="460" height="100"/><br>

A Terraform module that deploys a Lambda function to monitor AWS CloudTrail events and send real-time Slack alerts when infrastructure changes occur in your AWS account.

## Architecture

```
CloudTrail → S3 Bucket → S3 Notification → Lambda → Slack Webhook
```

1. CloudTrail records all API calls and writes log files to S3 every ~5 minutes
2. S3 fires a notification when a new log file lands
3. Lambda downloads the file, parses all CloudTrail events, and filters them against your rules
4. Matching events are posted to your Slack webhook

## Prerequisites

- An existing CloudTrail trail writing logs to an S3 bucket in the same AWS account
- A Slack incoming webhook URL
- Python 3.10 available in your system PATH (`python3.10 --version`)
- Terraform >= 1.3.0

## Usage

Create a caller directory with the following files:

### main.tf
```hcl
provider "aws" {
  region = "us-east-1"
}

module "cloudtrail_to_slack" {
  source = "sudo-terraform-aws-modules/cloudtrail-slack/aws"

  project_name                   = "myproject"
  cloudtrail_logs_s3_bucket_name = "my-cloudtrail-logs-bucket"
  slack_webhook_url              = var.slack_webhook_url

  # Optional: override default events to track
  events_to_track = "AuthorizeSecurityGroupIngress,RevokeSecurityGroupIngress,CreateSecurityGroup,DeleteSecurityGroup"

  # Optional: ignore automated/CI events
  ignore_rules = "event.get('userIdentity.sessionContext.sessionIssuer.userName','').startswith('GH-OIDC')|event.get('userIdentity.userName','') == 'github_action_staging'"

  rules_separator = "|"

  tags = {
    Environment = "production"
  }
}
```

### variables.tf
```hcl
variable "slack_webhook_url" {
  type      = string
  sensitive = true
}
```

### Deploy
```bash
export TF_VAR_slack_webhook_url="https://hooks.slack.com/services/xxx/yyy/zzz"
terraform init
terraform plan
terraform apply
```

For detailed step-by-step instructions see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

---

## Required Variables

| Name | Description |
|------|-------------|
| `project_name` | Short identifier for the project. Used as prefix for all resource names. Lowercase letters, numbers and hyphens only. e.g. `acme`, `myproject` |
| `slack_webhook_url` | Slack incoming webhook URL. **Pass via `TF_VAR_slack_webhook_url` - never hardcode in any file.** |
| `cloudtrail_logs_s3_bucket_name` | Name of the existing S3 bucket where CloudTrail logs are stored. |

## Optional Variables

| Name | Default | Description |
|------|---------|-------------|
| `events_to_track` | *(see variables.tf)* | Comma-separated list of CloudTrail event names to alert on. |
| `ignore_rules` | `""` | Pipe-separated Python expressions. Events matching any rule are silently discarded. |
| `rules_separator` | `"\|"` | Separator between ignore_rules entries. |
| `lambda_timeout_seconds` | `30` | Lambda execution timeout in seconds. |
| `lambda_memory_mb` | `256` | Lambda memory in MB. |
| `log_level` | `"INFO"` | Lambda log level. One of: DEBUG, INFO, WARNING, ERROR. |
| `tags` | `{}` | Additional tags applied to all resources. |

## Outputs

| Name | Description |
|------|-------------|
| `lambda_function_arn` | ARN of the deployed Lambda function. |
| `lambda_function_name` | Name of the Lambda function. |
| `cloudwatch_log_group_name` | CloudWatch log group for Lambda logs. |
| `iam_role_arn` | ARN of the Lambda IAM role. |

## Resources Created

| Resource | Name Pattern |
|----------|-------------|
| `aws_lambda_function` | `{project_name}-cloudtrail-to-slack` |
| `aws_iam_role` | `{project_name}-cloudtrail-to-slack-lambda-role` |
| `aws_iam_role_policy` | `{project_name}-cloudtrail-to-slack-lambda-policy` |
| `aws_cloudwatch_log_group` | `/aws/lambda/{project_name}-cloudtrail-to-slack` |
| `aws_lambda_permission` | Allows S3 bucket to invoke Lambda |
| `aws_s3_bucket_notification` | Wires CloudTrail S3 bucket to Lambda |

## Ignore Rules Examples

Ignore GitHub Actions automated deployments:
```
event.get('userIdentity.sessionContext.sessionIssuer.userName','').startswith('GH-OIDC')
```

Ignore a specific IAM user:
```
event.get('userIdentity.userName','') == 'github_action_staging'
```

Ignore AWS service automated calls:
```
event.get('userIdentity.type','') == 'AWSService'
```

Combine multiple rules with `|` separator:
```
event.get('userIdentity.sessionContext.sessionIssuer.userName','').startswith('GH-OIDC')|event.get('userIdentity.userName','') == 'github_action_staging'|event.get('userIdentity.type','') == 'AWSService'
```
