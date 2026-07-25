# Test-only requirement: mock_provider needs Terraform >= 1.7 / OpenTofu >= 1.7.
# The module itself still supports >= 1.5, so versions.tf is intentionally unchanged.
mock_provider "google" {}

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
