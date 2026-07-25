# terraform-google-service-accounts

Terraform module that manages [Google Cloud](https://cloud.google.com/)
service accounts (`google_service_account`). It creates one or more accounts
from a map, optionally issues keys, and grants project-level roles.

## Usage

```hcl
module "service_accounts" {
  source = "github.com/moveeeax/terraform-google-service-accounts"

  project_id = var.project_id

  accounts = {
    "ci-deployer" = {
      display_name = "CI deployer"
    }
  }

  project_roles = {
    "ci-deployer|roles/run.admin" = "roles/run.admin"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Security notes

**Service account keys are off by default and need a second, explicit opt-in.**
A user-managed key (`google_service_account_key`) is a long-lived credential that
never expires on its own, and its private key is stored **in Terraform state in
plaintext** as well as being surfaced through the `private_keys` output. Leaked
JSON key files are the most common way Google Cloud credentials are compromised.

Prefer, in order:

1. [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
   for CI and for workloads outside Google Cloud.
2. An attached service account (GKE Workload Identity, Cloud Run, GCE) for
   workloads inside Google Cloud.
3. Short-lived tokens via
   [service account impersonation](https://cloud.google.com/iam/docs/service-account-impersonation).

Only if none of those is possible:

```hcl
module "service_accounts" {
  # ...
  allow_service_account_keys = true # acknowledges the risk described above

  accounts = {
    "legacy-uploader" = {
      create_key = true
    }
  }
}
```

Setting `create_key = true` without `allow_service_account_keys = true` fails at
plan time with an explanatory error instead of silently minting a credential. If
you do use keys, make sure the state backend is encrypted and access-controlled,
and rotate them on a schedule.

**Primitive roles are gated too.** `roles/owner`, `roles/editor` and `roles/viewer`
apply to every resource in the project. Granting one of them through
`project_roles` fails at plan time unless `allow_primitive_roles = true`. Use a
predefined or custom role instead.

**Role grants are additive.** Roles are granted with `google_project_iam_member`,
which adds a single member and leaves every other member of that role alone. The
module deliberately does not use `google_project_iam_binding`, which is
authoritative for a role and would silently remove every other member of it.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

Running the suite in [`tests/`](tests) additionally needs Terraform or OpenTofu
>= 1.7 for `mock_provider`; the module itself still works on >= 1.5.

## Inputs

| Name                         | Description                                                                                       | Type          | Default | Required |
|------------------------------|---------------------------------------------------------------------------------------------------|---------------|---------|:--------:|
| `project_id`                 | ID of the project in which to create the accounts.                                                 | `string`      | n/a     |   yes    |
| `accounts`                   | Service accounts keyed by account id. Each key must be 6-30 chars, `[a-z][a-z0-9-]*[a-z0-9]`.      | `map(object)` | `{}`    |    no    |
| `project_roles`              | Project roles keyed by `<account_id>\|<role>`; the value is the role to grant.                    | `map(string)` | `{}`    |    no    |
| `allow_service_account_keys` | Must be `true` before an account with `create_key = true` is issued a key. See "Security notes".   | `bool`        | `false` |    no    |
| `allow_primitive_roles`      | Must be `true` before `roles/owner`, `roles/editor` or `roles/viewer` may be granted.              | `bool`        | `false` |    no    |

### `accounts` object

| Field          | Type     | Default | Description                                                          |
|----------------|----------|---------|-----------------------------------------------------------------------|
| `display_name` | `string` | `null`  | Human-readable name for the account.                                  |
| `description`  | `string` | `null`  | Description of the account.                                           |
| `create_key`   | `bool`   | `false` | Issue a user-managed key. Also requires `allow_service_account_keys`. |

## Outputs

| Name           | Description                                                                     |
|----------------|----------------------------------------------------------------------------------|
| `emails`       | Email addresses of the created accounts.                                         |
| `ids`          | Identifiers of the created accounts.                                             |
| `private_keys` | Base64 private keys for accounts with keys. Sensitive; empty unless keys are on. |

## Testing

```sh
terraform init -backend=false
terraform test
```

The suite uses `mock_provider "google" {}`, so it needs no credentials and no
network access.

## License

[MIT](LICENSE)
