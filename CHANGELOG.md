# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `accounts[*].workload_identity_principals`: principals granted
  `roles/iam.workloadIdentityUser` on that account through
  `google_service_account_iam_member`. Accepts `principal://` and
  `principalSet://` Workload Identity Federation principals and GKE
  `serviceAccount:<project>.svc.id.goog[<namespace>/<ksa>]` members. Defaults
  to `[]`, so existing plans are unchanged.

[Unreleased]: https://github.com/moveeeax/terraform-google-service-accounts/compare/v1.1.0...HEAD
