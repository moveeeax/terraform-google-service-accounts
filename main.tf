locals {
  # Primitive (a.k.a. basic) roles apply to every resource in the project.
  primitive_roles = ["roles/owner", "roles/editor", "roles/viewer"]

  # Key format is validated in variables.tf, so the split is safe here.
  role_grants = {
    for k, role in var.project_roles : k => {
      account_id = split("|", k)[0]
      role       = role
    }
  }
}

resource "google_service_account" "this" {
  for_each = var.accounts

  project      = var.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description
}

# WARNING: this creates a long-lived, non-expiring credential whose private key is
# stored in Terraform state in plaintext. It is gated behind var.allow_service_account_keys
# on purpose. Prefer Workload Identity Federation or an attached service account.
resource "google_service_account_key" "this" {
  for_each = { for k, v in var.accounts : k => v if v.create_key }

  service_account_id = google_service_account.this[each.key].name

  lifecycle {
    precondition {
      condition     = var.allow_service_account_keys
      error_message = "Service account \"${each.key}\" sets create_key = true, but var.allow_service_account_keys is false. A user-managed key is a long-lived credential and its private key is written to Terraform state in plaintext. Prefer Workload Identity Federation, an attached service account, or short-lived tokens; set allow_service_account_keys = true only if you have accepted that risk."
    }
  }
}

# google_project_iam_member is deliberately non-authoritative: it adds this one member to
# the role and leaves every other member of that role alone. Do NOT switch this to
# google_project_iam_binding, which would strip all other members of the role.
resource "google_project_iam_member" "this" {
  for_each = local.role_grants

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this[each.value.account_id].email}"

  lifecycle {
    precondition {
      condition     = contains(keys(var.accounts), each.value.account_id)
      error_message = "var.project_roles key \"${each.key}\" refers to account id \"${each.value.account_id}\", which is not present in var.accounts."
    }

    precondition {
      condition     = var.allow_primitive_roles || !contains(local.primitive_roles, each.value.role)
      error_message = "var.project_roles grants the primitive role \"${each.value.role}\" to \"${each.value.account_id}\". Primitive roles apply to every resource in the project. Use a predefined or custom role, or set allow_primitive_roles = true to override."
    }
  }
}
