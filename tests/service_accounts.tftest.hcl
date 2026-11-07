# Test-only requirement: mock_provider needs Terraform >= 1.7 / OpenTofu >= 1.7.
# The module itself still supports >= 1.5, so versions.tf is intentionally unchanged.
mock_provider "google" {
  # The provider validates service_account_id on google_service_account_iam_member,
  # so the mocked account needs a well-formed name instead of a random string.
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/example-project/serviceAccounts/mock-account@example-project.iam.gserviceaccount.com"
      email = "mock-account@example-project.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id = "example-project"
}

run "defaults_create_no_keys" {
  variables {
    accounts = {
      "app-runtime" = {
        display_name = "Application runtime"
      }
    }
  }

  assert {
    condition     = length(google_service_account.this) == 1
    error_message = "Expected exactly one service account to be planned."
  }

  assert {
    condition     = length(google_service_account_key.this) == 0
    error_message = "No user-managed service account key may be created unless create_key is explicitly set."
  }
}

run "role_grant_is_non_authoritative_and_targets_the_account" {
  variables {
    accounts = {
      "app-runtime" = {}
    }
    project_roles = {
      "app-runtime|roles/storage.objectViewer" = "roles/storage.objectViewer"
    }
  }

  assert {
    condition     = google_project_iam_member.this["app-runtime|roles/storage.objectViewer"].role == "roles/storage.objectViewer"
    error_message = "The granted role must come from the map value."
  }

  assert {
    condition     = startswith(google_project_iam_member.this["app-runtime|roles/storage.objectViewer"].member, "serviceAccount:")
    error_message = "The member must be the service account principal."
  }
}

run "rejects_too_short_account_id" {
  command = plan

  variables {
    accounts = {
      "ci" = {}
    }
  }

  expect_failures = [var.accounts]
}

run "rejects_uppercase_account_id" {
  command = plan

  variables {
    accounts = {
      "CI-Deployer" = {}
    }
  }

  expect_failures = [var.accounts]
}

run "rejects_account_id_with_trailing_hyphen" {
  command = plan

  variables {
    accounts = {
      "ci-deployer-" = {}
    }
  }

  expect_failures = [var.accounts]
}

run "rejects_malformed_project_roles_key" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {}
    }
    project_roles = {
      "ci-deployer" = "roles/run.admin"
    }
  }

  expect_failures = [var.project_roles]
}

run "rejects_project_roles_value_that_is_not_a_role" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {}
    }
    project_roles = {
      "ci-deployer|run.admin" = "run.admin"
    }
  }

  expect_failures = [var.project_roles]
}

run "service_account_keys_require_explicit_opt_in" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {
        create_key = true
      }
    }
  }

  expect_failures = [google_service_account_key.this]
}

run "service_account_keys_are_created_once_allowed" {
  variables {
    allow_service_account_keys = true
    accounts = {
      "ci-deployer" = {
        create_key = true
      }
    }
  }

  assert {
    condition     = length(google_service_account_key.this) == 1
    error_message = "Expected a key to be planned once allow_service_account_keys is true."
  }
}

run "primitive_roles_require_explicit_opt_in" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {}
    }
    project_roles = {
      "ci-deployer|roles/editor" = "roles/editor"
    }
  }

  expect_failures = [google_project_iam_member.this]
}

run "primitive_roles_are_granted_once_allowed" {
  variables {
    allow_primitive_roles = true
    accounts = {
      "ci-deployer" = {}
    }
    project_roles = {
      "ci-deployer|roles/editor" = "roles/editor"
    }
  }

  assert {
    condition     = google_project_iam_member.this["ci-deployer|roles/editor"].role == "roles/editor"
    error_message = "Expected the primitive role to be granted once allow_primitive_roles is true."
  }
}

run "rejects_role_for_unknown_account" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {}
    }
    project_roles = {
      "does-not-exist|roles/run.admin" = "roles/run.admin"
    }
  }

  expect_failures = [google_project_iam_member.this]
}

run "no_account_iam_by_default" {
  variables {
    accounts = {
      "app-runtime" = {}
    }
  }

  assert {
    condition     = length(google_service_account_iam_member.this) == 0
    error_message = "No grants on the account may be planned unless workload_identity_principals is set."
  }
}

run "workload_identity_principals_get_workload_identity_user" {
  variables {
    accounts = {
      "ci-deployer" = {
        workload_identity_principals = [
          "principalSet://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/github/attribute.repository/moveeeax/app",
          "serviceAccount:example-project.svc.id.goog[apps/deployer]",
          "serviceAccount:example-project.svc.id.goog[apps/deployer]",
        ]
      }
    }
  }

  assert {
    condition     = length(google_service_account_iam_member.this) == 2
    error_message = "Expected one grant per distinct principal."
  }

  assert {
    condition = alltrue([
      for g in google_service_account_iam_member.this : g.role == "roles/iam.workloadIdentityUser"
    ])
    error_message = "Workload Identity principals must be granted roles/iam.workloadIdentityUser."
  }

  assert {
    condition     = google_service_account_iam_member.this["ci-deployer|roles/iam.workloadIdentityUser|serviceAccount:example-project.svc.id.goog[apps/deployer]"].member == "serviceAccount:example-project.svc.id.goog[apps/deployer]"
    error_message = "The member must be the principal exactly as given."
  }
}

run "rejects_workload_identity_principal_that_is_a_plain_user" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {
        workload_identity_principals = ["user:someone@example.com"]
      }
    }
  }

  expect_failures = [var.accounts]
}

run "rejects_workload_identity_principal_with_malformed_gke_member" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {
        workload_identity_principals = ["serviceAccount:example-project.svc.id.goog[deployer]"]
      }
    }
  }

  expect_failures = [var.accounts]
}

run "impersonators_and_users_are_granted_on_the_account" {
  variables {
    accounts = {
      "ci-deployer" = {
        impersonators = ["group:platform@example.com"]
        users         = ["serviceAccount:cloudbuild@example-project.iam.gserviceaccount.com"]
      }
    }
  }

  assert {
    condition     = length(google_service_account_iam_member.this) == 2
    error_message = "Expected one grant for the impersonator and one for the user."
  }

  assert {
    condition     = google_service_account_iam_member.this["ci-deployer|roles/iam.serviceAccountTokenCreator|group:platform@example.com"].member == "group:platform@example.com"
    error_message = "Impersonators must be granted roles/iam.serviceAccountTokenCreator."
  }

  assert {
    condition     = google_service_account_iam_member.this["ci-deployer|roles/iam.serviceAccountUser|serviceAccount:cloudbuild@example-project.iam.gserviceaccount.com"].role == "roles/iam.serviceAccountUser"
    error_message = "Users must be granted roles/iam.serviceAccountUser."
  }

  assert {
    condition     = length(google_project_iam_member.this) == 0
    error_message = "Impersonation rights must not be granted at project level."
  }
}

run "same_member_can_hold_several_roles_on_one_account" {
  variables {
    accounts = {
      "ci-deployer" = {
        impersonators = ["user:alice@example.com"]
        users         = ["user:alice@example.com"]
      }
    }
  }

  assert {
    condition     = length(google_service_account_iam_member.this) == 2
    error_message = "The same member listed under impersonators and users must get both roles."
  }
}

run "rejects_all_users_as_impersonator" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {
        impersonators = ["allUsers"]
      }
    }
  }

  expect_failures = [var.accounts]
}

run "rejects_user_without_member_type" {
  command = plan

  variables {
    accounts = {
      "ci-deployer" = {
        users = ["alice@example.com"]
      }
    }
  }

  expect_failures = [var.accounts]
}
