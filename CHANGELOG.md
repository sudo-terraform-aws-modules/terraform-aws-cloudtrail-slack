# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-25

### Added

- Terraform module to deploy AWS Lambda for CloudTrail event monitoring
- S3 event notification trigger from CloudTrail log bucket to Lambda
- Lambda function (Python 3.12) that parses CloudTrail events and forwards alerts to Slack
- Configurable event filter rules via `cloudtrail_filter_rules` variable
- Support for custom IAM role or auto-created role via `create_iam_role` variable
- Slack webhook integration with structured message formatting
- IAM policy granting Lambda read access to the CloudTrail S3 bucket
- CloudWatch Logs log group for Lambda with configurable retention
- Outputs for Lambda function ARN, name, role ARN, and log group name
- `versions.tf` pinning AWS provider `~> 5.0` and Terraform `>= 1.3`
- `DEPLOYMENT.md` with step-by-step deployment instructions

[Unreleased]: https://github.com/amaanulhaqsiddiqui/terraform-aws-cloudtrail-slack/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/amaanulhaqsiddiqui/terraform-aws-cloudtrail-slack/releases/tag/v0.1.0
