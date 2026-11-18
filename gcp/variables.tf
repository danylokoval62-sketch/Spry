variable "project_id" {
  type        = string
  description = "Permanent, globally unique, e.g. spry-<yourname>-2026"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "image" {
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
  description = "Only used at creation. New images go out with make deploy-gcp-backend (ignore_changes)"
}

variable "db_name" {
  type    = string
  default = "spry"
}

variable "db_user" {
  type    = string
  default = "spry"
}

# Workload Identity Federation for HCP Terraform: numeric IDs, names can be re-registered
variable "hcp_organization_id" {
  type        = string
  description = "HCP Terraform organization ID (org-...), Settings -> Organization"
}

variable "hcp_workspace_id" {
  type        = string
  description = "HCP Terraform workspace ID (ws-...) of spry-gcp"
}
