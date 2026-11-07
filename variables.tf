variable "project_id" {
  description = "ID of the project in which to create the service accounts."
  type        = string
}

variable "accounts" {
  description = "Service accounts to create, keyed by account id (the part before @)."
  type = map(object({
    display_name = optional(string)
    description  = optional(string)
    create_key   = optional(bool, false)

    # Granted roles/iam.workloadIdentityUser on this account only.
    workload_identity_principals = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for id in keys(var.accounts) : can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", id))
    ])
    error_message = "Each key of var.accounts becomes the account_id of a google_service_account and must satisfy Google's rules: 6-30 characters, starting with a lowercase letter, ending with a lowercase letter or digit, containing only lowercase letters, digits and hyphens."
  }

  validation {
    condition = alltrue(flatten([
      for sa in values(var.accounts) : [
        for m in sa.workload_identity_principals :
        can(regex("^(principal|principalSet)://iam\\.googleapis\\.com/.+$", m)) ||
        can(regex("^serviceAccount:[a-z0-9.:-]+\\.svc\\.id\\.goog\\[[^/\\]]+/[^/\\]]+\\]$", m))
      ]
    ]))
    error_message = "Each entry of workload_identity_principals must be a Workload Identity Federation principal (\"principal://iam.googleapis.com/...\" or \"principalSet://iam.googleapis.com/...\") or a GKE Workload Identity member (\"serviceAccount:<project>.svc.id.goog[<namespace>/<ksa>]\")."
  }
}

variable "project_roles" {
  description = "Project roles to grant, keyed by \"<account_id>|<role>\"; the referenced account must exist in var.accounts. Granted with google_project_iam_member, so other members already holding the same role are left untouched."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.project_roles) :
      length(split("|", k)) == 2 && length(split("|", k)[0]) > 0 && length(split("|", k)[1]) > 0
    ])
    error_message = "Each key of var.project_roles must be \"<account_id>|<role>\", with exactly one \"|\" and non-empty parts, for example \"ci-deployer|roles/run.admin\"."
  }

  validation {
    condition = alltrue([
      for v in values(var.project_roles) :
      can(regex("^(roles/[A-Za-z0-9_.]+|(projects|organizations)/[^/]+/roles/[A-Za-z0-9_.]+)$", v))
    ])
    error_message = "Each value of var.project_roles must be a role name such as \"roles/run.admin\", or a custom role such as \"projects/<project>/roles/<id>\" or \"organizations/<org>/roles/<id>\"."
  }
}

variable "allow_service_account_keys" {
  description = <<-EOT
    Acknowledgement required before any account with create_key = true is actually issued a
    user-managed key. User-managed service account keys are long-lived credentials that never
    expire on their own, are the most common source of leaked Google Cloud credentials, and
    their private key is written to Terraform state in plaintext (and exposed through the
    private_keys output). Prefer Workload Identity Federation, attached service accounts or
    short-lived tokens. Set to true only when you have no alternative and have accepted that risk.
  EOT
  type        = bool
  default     = false
}

variable "allow_primitive_roles" {
  description = "Acknowledgement required before roles/owner, roles/editor or roles/viewer may be granted through var.project_roles. Primitive roles apply to every resource in the project; prefer predefined or custom roles."
  type        = bool
  default     = false
}
