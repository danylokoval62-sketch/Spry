# ---------- APIs: off by default, so a fresh project is reproducible ----------
locals {
  apis = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "firebasehosting.googleapis.com",
  ]
}

resource "google_project_service" "api" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------- Service accounts: one per program, no default compute SA ----------
resource "google_service_account" "terraform" {
  account_id   = "spry-terraform"
  display_name = "Terraform (HCP) for Spry"
  depends_on   = [google_project_service.api]
}

resource "google_service_account" "api" {
  account_id   = "spry-api"
  display_name = "Spry API on Cloud Run"
  depends_on   = [google_project_service.api]
}

resource "google_project_iam_member" "terraform" {
  for_each = toset([
    "roles/run.admin",
    "roles/cloudsql.admin",
    "roles/artifactregistry.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountUser",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.terraform.member
}

# The API may only connect to Cloud SQL and read its own secret (below)
resource "google_project_iam_member" "api_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.api.member
}

# ---------- Workload Identity Federation: HCP Terraform, no JSON key ----------
resource "google_iam_workload_identity_pool" "hcp" {
  workload_identity_pool_id = "hcp-terraform"
  depends_on                = [google_project_service.api]
}

resource "google_iam_workload_identity_pool_provider" "hcp" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.hcp.workload_identity_pool_id
  workload_identity_pool_provider_id = "hcp-terraform"

  attribute_mapping = {
    "google.subject"                      = "assertion.sub"
    "attribute.terraform_organization_id" = "assertion.terraform_organization_id"
    "attribute.terraform_workspace_id"    = "assertion.terraform_workspace_id"
  }
  attribute_condition = "assertion.terraform_organization_id == \"${var.hcp_organization_id}\" && assertion.terraform_workspace_id == \"${var.hcp_workspace_id}\""

  oidc {
    issuer_uri = "https://app.terraform.io"
  }
}

resource "google_service_account_iam_member" "hcp_impersonates_terraform" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.hcp.name}/attribute.terraform_workspace_id/${var.hcp_workspace_id}"
}

# ---------- Artifact Registry ----------
resource "google_artifact_registry_repository" "spry" {
  repository_id = "spry"
  format        = "DOCKER"
  location      = var.region
  depends_on    = [google_project_service.api]
}

# ---------- Cloud SQL: db-f1-micro, 10 GB SSD. Does NOT pause on idle ----------
resource "google_sql_database_instance" "spry" {
  name                = "spry-pg"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = false # lab: terraform destroy must work

  settings {
    tier              = "db-f1-micro"
    edition           = "ENTERPRISE"
    disk_type         = "PD_SSD"
    disk_size         = 10
    availability_type = "ZONAL"

    # Stop to save $7.67/mo: gcloud sql instances patch spry-pg --activation-policy=NEVER
    # Leave the policy to the gcloud command, so a plan does not start it again.
    activation_policy = "ALWAYS"
  }

  lifecycle {
    ignore_changes = [settings[0].activation_policy]
  }

  depends_on = [google_project_service.api]
}

resource "google_sql_database" "spry" {
  name     = var.db_name
  instance = google_sql_database_instance.spry.name
}

resource "random_password" "db" {
  length  = 32
  special = false # goes into a URL
}

resource "google_sql_user" "spry" {
  name     = var.db_user
  instance = google_sql_database_instance.spry.name
  password = random_password.db.result
}

# The whole DATABASE_URL is the secret: Cloud Run cannot interpolate env vars.
# Unix socket /cloudsql/<connection> is what the Cloud SQL connector mounts.
resource "google_secret_manager_secret" "database_url" {
  secret_id = "spry-database-url"
  replication {
    auto {}
  }
  depends_on = [google_project_service.api]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql+psycopg://${var.db_user}:${random_password.db.result}@/${var.db_name}?host=/cloudsql/${google_sql_database_instance.spry.connection_name}"
}

resource "google_secret_manager_secret_iam_member" "api_reads" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.api.member
}

# ---------- Cloud Run: scales to zero ----------
resource "google_cloud_run_v2_service" "api" {
  name                = "spry-api"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.spry.connection_name]
      }
    }

    containers {
      image = var.image

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }

  depends_on = [google_secret_manager_secret_iam_member.api_reads, google_project_iam_member.api_sql]
}

# Public: the Spry API has no auth of its own yet (sign-in is still on AWS).
# ponytail: add token checking before putting anything private behind it.
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.api.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
