terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "service_accounts" {
  source = "../.."

  project_id = var.project_id

  # Account ids must be 6-30 characters, so "app" would be rejected by Google.
  accounts = {
    "app-runtime" = {
      display_name = "Application service account"
    }
  }

  # No create_key and no allow_service_account_keys: this example issues no
  # long-lived credentials. Attach the account to the workload instead.
  project_roles = {
    "app-runtime|roles/storage.objectViewer" = "roles/storage.objectViewer"
  }
}

variable "project_id" {
  description = "Project ID to create the example service accounts in."
  type        = string
}

variable "region" {
  description = "Region for the google provider."
  type        = string
  default     = "us-central1"
}

output "service_account_emails" {
  value = module.service_accounts.emails
}
