variable "project_name" {
  description = "Short identifier for the project. Used as a prefix for all resource names (e.g. 'acme', 'globex'). Lowercase letters, numbers, and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL. Pass via TF_VAR_slack_webhook_url environment variable — do not hardcode in any file."
  type        = string
  sensitive   = true
}

variable "cloudtrail_logs_s3_bucket_name" {
  description = "Name of the existing S3 bucket where CloudTrail logs are stored."
  type        = string
}

variable "events_to_track" {
  description = "Comma-separated list of CloudTrail event names to send Slack alerts for."
  type        = string
  default     = "AuthorizeSecurityGroupIngress,AuthorizeSecurityGroupEgress,RevokeSecurityGroupIngress,RevokeSecurityGroupEgress,CreateSecurityGroup,DeleteSecurityGroup,CreateVpc,DeleteVpc,ModifyVpcAttribute,CreateSubnet,DeleteSubnet,CreateRouteTable,DeleteRouteTable,CreateRoute,DeleteRoute,CreateInternetGateway,DeleteInternetGateway,AttachInternetGateway,DetachInternetGateway,CreateNatGateway,DeleteNatGateway,CreateDBInstance,DeleteDBInstance,ModifyDBInstance,CreateDBCluster,DeleteDBCluster,ModifyDBCluster,CreateLoadBalancer,DeleteLoadBalancer,ModifyLoadBalancerAttributes,CreateTargetGroup,DeleteTargetGroup,CreateListener,DeleteListener,ModifyListener,CreateAutoScalingGroup,DeleteAutoScalingGroup,UpdateAutoScalingGroup,TerminateInstances,CreateKeyPair,DeleteKeyPair,CreateCluster,DeleteCluster,UpdateCluster,CreateCapacityProvider,DeleteCapacityProvider"
}

variable "ignore_rules" {
  description = "Rules to suppress specific events. Each rule is a Python expression evaluated against the flattened CloudTrail event. Separate multiple rules with the rules_separator character."
  type        = string
  default     = "event.get('userIdentity.sessionContext.sessionIssuer.userName','').startswith('GH-OIDC')|event.get('userIdentity.userName','') == 'github_action_staging'|event.get('userIdentity.invokedBy','') == 'ssm.amazonaws.com'|event.get('userIdentity.invokedBy','') == 'ecs.amazonaws.com'|event.get('userIdentity.invokedBy','') == 'autoscaling.amazonaws.com'|event.get('userIdentity.type','') == 'AWSService'|event.get('eventName','') == 'UpdateService'|event.get('eventName','') == 'CreateService'|event.get('eventName','') == 'DeleteService'|event.get('eventName','') == 'RegisterTaskDefinition'|event.get('eventName','') == 'DeregisterTaskDefinition'|event.get('eventName','') == 'RunTask'|event.get('eventName','') == 'StopTask'"
}

variable "rules_separator" {
  description = "Separator character used between ignore_rules entries. Use | if your rules contain commas."
  type        = string
  default     = "|"
}

variable "lambda_timeout_seconds" {
  description = "Maximum seconds the Lambda function is allowed to run. Increase if you have high CloudTrail log volume."
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout_seconds >= 3 && var.lambda_timeout_seconds <= 900
    error_message = "lambda_timeout_seconds must be between 3 and 900."
  }
}

variable "lambda_memory_mb" {
  description = "Memory allocated to the Lambda function in MB."
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_mb >= 128 && var.lambda_memory_mb <= 10240
    error_message = "lambda_memory_mb must be between 128 and 10240."
  }
}

variable "log_level" {
  description = "Log level for the Lambda function."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
