variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "sender_email" {
  description = "SES-verified email address used as the sender for debrief emails"
  type        = string
}

variable "notify_email" {
  description = "Email address that receives debrief summaries (can match sender_email)"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name for session continuity"
  type        = string
  default     = "ReadyCheckSessions"
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "ready-check-backend"
}

variable "elevenlabs_agent_id" {
  description = "The ElevenLabs agent ID this frontend connects to"
  type        = string
}

variable "cognito_domain_prefix" {
  description = "Unique prefix for the Cognito Hosted UI domain (must be globally unique)"
  type        = string
}

variable "eb_cname_prefix" {
  description = "Unique prefix for the Elastic Beanstalk environment URL (must be globally unique per region)"
  type        = string
}

variable "eb_solution_stack_name" {
  description = "Elastic Beanstalk solution stack — verified against available stacks in us-east-1"
  type        = string
  default     = "64bit Amazon Linux 2023 v6.11.8 running Node.js 22"
}

variable "admin_email" {
  description = "Your real email — used to create your own Cognito login"
  type        = string
}

variable "admin_given_name" {
  description = "Your first name, used by the agent to greet you"
  type        = string
}
