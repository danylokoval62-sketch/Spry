variable "project_name" {
  type    = string
  default = "spry"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "domain" {
  type    = string
  default = "spry-koval.me"
}

# --- auth ---

variable "domain_prefix" {
  type    = string
  default = "spry-koval"
}

variable "site_url" {
  type    = string
  default = "https://app.spry-koval.me/"
}

variable "local_url" {
  type    = string
  default = "http://localhost:5173/"
}

variable "google_client_id" {
  type = string
}

variable "google_client_secret" {
  type      = string
  sensitive = true
}

# --- reports ---

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type        = string
  description = "The API's security group, which RDS already allows on 5432"
}

variable "image_uri" {
  type        = string
  description = "Backend image in ECR. Only used at creation: new images go out with make deploy-reports / deploy-ai"
}

variable "database_url" {
  type      = string
  sensitive = true
}

variable "recipients" {
  type        = string
  description = "Comma-separated inboxes; in the SES sandbox each must be a verified identity"
}

variable "schedule_expression" {
  type    = string
  default = "cron(0 7 ? * MON *)"
}

variable "fail_week" {
  type        = string
  default     = ""
  description = "Make the builder raise for this ISO week, to exercise the DLQ"
}

# --- ai ---

variable "parser_model" {
  type    = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "bedrock_region" {
  type    = string
  default = "us-east-1"
}

variable "allowed_origins" {
  type    = list(string)
  default = ["https://app.spry-koval.me", "http://localhost:5173"]
}

variable "budget_email" {
  type        = string
  default     = ""
  description = "Gets a mail at 80% (forecast) and 100% of the monthly budget; empty = no budget"
}
