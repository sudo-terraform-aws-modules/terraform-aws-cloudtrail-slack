# Deployment Guide

## Prerequisites

Before deploying, ensure the following are in place:

- [ ] AWS CLI configured and authenticated to the target account
- [ ] Terraform >= 1.3.0 installed
- [ ] Python 3.10 installed (`python3.10 --version`)
- [ ] An existing CloudTrail trail writing logs to an S3 bucket in the same account
- [ ] A Slack incoming webhook URL ready

---

## Step-by-Step Deployment

### 1. Create your caller directory

```
my-deployment/
├── main.tf
├── provider.tf
└── terraform.tfvars   ← do NOT put slack_webhook_url here
```

### 2. Write main.tf

```hcl
module "cloudtrail_to_slack" {
  source = "git::https://github.com/<your-org>/terraform-cloudtrail-to-slack.git"

  project_name                   = "myproject"
  cloudtrail_logs_s3_bucket_name = "my-cloudtrail-logs-123456789"
  slack_webhook_url              = var.slack_webhook_url

  ignore_rules    = "event.get('userIdentity.sessionContext.sessionIssuer.userName','').startswith('GH-OIDC')|event.get('userIdentity.type','') == 'AWSService'"
  rules_separator = "|"

  tags = {
    Environment = "staging"
  }
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}
```

### 3. Write provider.tf

```hcl
provider "aws" {
  region = "us-east-1"
}
```

### 4. Export the Slack webhook URL as an environment variable

```bash
export TF_VAR_slack_webhook_url="https://hooks.slack.com/services/xxx/yyy/zzz"
```

### 5. Verify you are in the correct AWS account

```bash
aws sts get-caller-identity
```

### 6. Deploy

```bash
terraform init
terraform plan
terraform apply
```

---

## Testing After Deployment

1. Go to EC2 → Security Groups in the AWS Console
2. Add or remove any inbound rule on any security group
3. Wait **3–5 minutes** for CloudTrail to write the log file to S3
4. Check Slack — you should receive an alert

---

## Variable Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `project_name` | Yes | Lowercase letters, numbers, hyphens only. Used to name all resources. |
| `slack_webhook_url` | Yes | Slack incoming webhook URL. Pass via `TF_VAR_slack_webhook_url`. |
| `cloudtrail_logs_s3_bucket_name` | Yes | Name of the S3 bucket where CloudTrail is writing logs. |
| `events_to_track` | No | Comma-separated CloudTrail event names to alert on. Has a sensible default. |
| `ignore_rules` | No | Pipe-separated Python expressions to suppress specific events. |
| `rules_separator` | No | Separator for ignore_rules. Default: `\|` |
| `lambda_timeout_seconds` | No | Default: 30 |
| `lambda_memory_mb` | No | Default: 256 |
| `log_level` | No | Default: INFO |
| `tags` | No | Map of additional tags. |

---

## What Gets Created

| Resource | Description |
|----------|-------------|
| Lambda Function | Processes CloudTrail log files and sends Slack alerts |
| IAM Role + Policy | Grants Lambda access to S3, CloudWatch Logs, and CloudWatch Metrics |
| CloudWatch Log Group | Stores Lambda execution logs (30 day retention) |
| S3 Bucket Notification | Triggers Lambda when new CloudTrail log files land in S3 |
| Lambda Permission | Allows S3 to invoke the Lambda function |

## What Does NOT Get Created

- CloudTrail trail (must already exist)
- S3 bucket for CloudTrail logs (must already exist)
- Slack webhook (must be created manually in Slack)
