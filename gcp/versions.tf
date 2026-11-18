terraform {
  required_version = ">= 1.10"

  # Its own workspace: one plan cannot break both clouds. Working directory = gcp
  cloud {
    organization = "ooad-danylokoval62-sketch"
    workspaces {
      name = "spry-gcp"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
