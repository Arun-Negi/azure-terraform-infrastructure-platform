# Architecture notes

## Goals
- Standardize resource naming, tags, and network layout.
- Reuse modules across independently managed environments.
- Keep Terraform state remote and isolated.
- Authenticate GitHub Actions to Azure with OIDC rather than long-lived client secrets.
- Require explicit review before applying infrastructure changes.

## Current scope
Each environment owns a resource group, virtual network, workload subnet, and network security group. The NSG has no inbound allow rules, so it does not expose a workload by default.

## State and locking
Azure Blob Storage provides remote state. The backend uses Blob leases for state locking. Use a unique state key per environment and tightly restrict access to the storage account/container.

## Production hardening
Add separate Azure identities/scopes, private state-storage networking, diagnostics, policy checks, controlled plan artifacts, drift detection, module versioning, and documented recovery procedures.
