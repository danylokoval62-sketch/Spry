output "api_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "image_repo" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.spry.repository_id}/backend"
}

output "sql_connection_name" {
  value = google_sql_database_instance.spry.connection_name
}

output "wif_provider" {
  description = "Set in the HCP workspace: TFC_GCP_WORKLOAD_PROVIDER_NAME"
  value       = google_iam_workload_identity_pool_provider.hcp.name
}

output "terraform_sa" {
  description = "Set in the HCP workspace: TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL"
  value       = google_service_account.terraform.email
}
