# Developer Design Standard: Extending the Azure Terraform Infrastructure Platform

**Status:** Proposed engineering standard  
**Audience:** Infrastructure engineers, service owners, reviewers, platform maintainers  
**Scope:** JSON-driven provisioning of Azure infrastructure through Terraform  
**Current platform scope:** Resource groups, optional virtual networks, and subnets; location fixed to Central US (`centralus`)

## 1. Purpose

This document defines how to extend the platform with additional Azure services without making end-user input complicated or weakening existing controls. End users should continue to configure infrastructure through JSON in VS Code. Terraform modules, schema rules, validations, tests, policy definitions, and the deployment pipeline should enforce the platform standards.

The goal is **one predictable interface, reusable implementation, and layered enforcement**—not a separate bespoke Terraform workflow for every service.

## 2. Design principles

1. **JSON is the user interface.** End users should not need to author HCL or call individual modules.
2. **Secure defaults.** Optional resources are omitted unless requested; avoid silently enabling public access or expensive tiers.
3. **Validate early and at multiple layers.** Editor schema checks improve feedback; Terraform validations and tests are mandatory; Azure Policy and Azure authorization provide server-side enforcement.
4. **Central region by default and by rule.** Current platform policy is Central US only. Do not add a user-controlled region field unless the platform owner explicitly changes this policy and updates all relevant controls.
5. **Modules own service implementation.** Root orchestration translates normalized JSON into module inputs; resource-specific implementation belongs in modules.
6. **Environment separation.** Keep environment inputs and state separate. Prefer separate Azure subscriptions for Dev, QA, Staging, and Production.
7. **Review before apply.** A successful plan is not an authorization to deploy. Production requires an approved plan and a protected deployment identity.
8. **Tests are part of the feature.** A service is not complete until valid and invalid input cases are tested.
9. **Avoid breaking contracts.** Treat JSON property names and meanings as a public API. Document and version breaking changes.
10. **Never commit credentials, state, or plan files.**

## 3. Target repository structure

Use this structure as the platform grows; migrate incrementally rather than moving every file in one large change.

```text
.
├── .github/
│   └── workflows/
│       ├── terraform-validate.yml
│       └── terraform-deploy.yml              # add when deployment automation is approved
├── .vscode/
│   └── settings.json
├── docs/
│   ├── architecture/
│   │   ├── 01-high-level-architecture.svg
│   │   ├── 02-cicd-deployment-flow.svg
│   │   └── 03-scalable-environments.svg
│   ├── DESIGN-STANDARD.md
│   └── decisions/                             # architecture decision records
├── examples/
│   ├── dev.json
│   ├── qa.json
│   ├── staging.json
│   └── prod.json
├── modules/
│   ├── resource-group/
│   ├── virtual-network/
│   ├── storage-account/                       # future example
│   ├── key-vault/                             # future example
│   └── container-registry/                    # future example
├── policies/
│   └── azure-policy/
├── schemas/
│   └── terraform-input.schema.json
├── tests/
│   └── ...                                    # module/service test coverage
├── locals.tf
├── main.tf
├── outputs.tf
├── providers.tf
├── variables.tf
├── versions.tf
└── README.md
```

The tree is a target, not a claim that every listed file or module already exists. Keep the current implementation working while each proposed area is introduced.

## 4. End-user JSON contract

### 4.1 Keep the input small and declarative

The JSON should describe **what** the user wants, not how Terraform creates it. Avoid exposing provider internals, resource addresses, module paths, lifecycle meta-arguments, or raw HCL.

Illustrative future shape (not all services below are implemented today):

```json
{
  "subscription_id": "00000000-0000-0000-0000-000000000000",
  "resource_groups": [
    {
      "name": "rg-app-dev-centralus",
      "tags": {
        "environment": "dev",
        "managed_by": "terraform",
        "owner": "platform-team"
      },
      "virtual_network": {
        "name": "vnet-app-dev",
        "address_space": ["10.20.0.0/16"],
        "subnets": [
          {
            "name": "snet-app",
            "address_prefixes": ["10.20.1.0/24"]
          }
        ]
      },
      "services": {
        "storage_account": {
          "name": "stappdev001",
          "tier": "Standard",
          "replication": "LRS",
          "public_network_access_enabled": false
        }
      }
    }
  ]
}
```

This is a design illustration only. Do not accept a new `services` block until its schema, Terraform type, module, restrictions, tests, documentation, and policy requirements have been implemented together.

### 4.2 JSON schema requirements

For each new property, define:
- Whether it is required or optional, and its default where appropriate.
- Data type, allowed values (`enum`), string length, pattern, array size and object shape.
- A clear `description` and useful `examples` for VS Code IntelliSense.
- `additionalProperties: false` for closed configuration objects unless extensibility is explicitly intended.
- Sensitive-data handling. Prefer references to secret stores over accepting secret values in JSON.
- Deprecated properties and migration notes, when applicable.

Associate the schema with the end-user JSON through `.vscode/settings.json`. Keep the schema permissive only where flexibility is intentional. Schema regex patterns are not a substitute for semantic validation.

### 4.3 Keep environment inputs separate

Use one input file per environment (for example, `examples/dev.json`, `examples/qa.json`, `examples/staging.json`, and `examples/prod.json`) and select it explicitly in the deployment workflow. Never use a developer's local file as an implicit production input. The repository should contain safe examples, not environment secrets.

## 5. Terraform implementation boundaries

### Root layer
- Parse and validate the input contract through typed variables.
- Enforce global invariants such as subscription expectations, Central US, naming conventions, and tag requirements.
- Wire dependencies and module calls.
- Expose stable outputs.
- Avoid placing large resource-specific implementations in the root module.

### Service module layer
Each service module should own its resource-specific Terraform resources and local validations. Prefer a small, explicit module interface over a large set of loosely typed maps.

A module should document:
- Supported resource types and provider versions.
- Required and optional inputs, defaults, outputs, and dependencies.
- Naming, SKU/tier, region, network, encryption, identity, and tag requirements.
- Whether replacement or deletion can cause data loss or downtime.
- Cost-sensitive settings and operational prerequisites.

Do not create a generic “deploy any Azure resource” escape hatch. Add explicit supported service types and typed configuration for each one.

## 6. Enforcement model: use every applicable layer

| Layer | Responsibility | Examples |
|---|---|---|
| VS Code JSON Schema | Fast authoring feedback | Required properties, types, enums, string lengths, simple patterns |
| Terraform type constraints and validation | Reject invalid configuration before planning | Central US only, name constraints, duplicates, CIDR syntax, approved SKUs |
| Terraform tests | Prove expected and rejected cases | Resource counts, omitted optional services, invalid tier and region |
| Azure Policy | Server-side governance at assigned scope | Allowed locations, required tags, public access restrictions, approved SKUs |
| Azure RBAC / workload identity | Control who can deploy and where | Least-privilege plan/apply identities, protected production access |
| Azure resource provider | Final API validation | Provider-specific limits, uniqueness, quota and feature availability |
| Plan review and approvals | Human change control | Destructive changes, production changes, cost and security impact |

**Important:** JSON Schema cannot reliably validate live Azure availability, global name uniqueness, quota, permissions, subnet overlap, or every cross-field rule. Terraform and Azure must continue to enforce these. Policy definitions have no effect until assigned at the appropriate scope.

## 7. Standard restrictions

Every new service must state which rules apply and where each is enforced.

### Global rules
- Location remains `centralus`; users cannot override it.
- Resource names follow Azure's service-specific constraints. Do not apply resource-group rules to every resource type.
- Require ownership and management tags where supported. Establish the platform's mandatory tag list with the governance owner.
- Reject unknown JSON properties unless a documented extension point is required.
- Use approved AzureRM provider versions and pin Terraform/tool versions in CI.
- Do not put secrets in JSON, source control, plan artifacts, logs, or outputs.
- Use private networking and disable public access by default when supported and compatible with the service's intended use.
- Validate service-specific SKU/tier, redundancy, encryption, TLS, identity, and networking choices against an explicit allowlist.
- Check dependency and data-loss behavior before allowing resource replacement or deletion.

### Service-specific rules
For every service, document:
1. Azure naming rules and length limits.
2. Allowed SKU/tier/replication values.
3. Supported location(s)—currently Central US only.
4. Network exposure and private endpoint requirements, if applicable.
5. Encryption, identity and access-control defaults.
6. Required tags and diagnostics.
7. Cross-field rules and dependencies.
8. Cost, quota and destructive-change considerations.
9. Terraform validation, automated tests, and Azure Policy coverage.

Do not invent SKU lists from memory. Verify them against the chosen AzureRM provider documentation and the service's current Azure support before adding an allowlist.

## 8. New service onboarding: required pull-request checklist

A developer adding a service must complete the following in order:

1. **Propose the input contract.** Add the service's properties to the JSON Schema with descriptions, examples, types, enums, length limits and required/optional behavior.
2. **Define typed Terraform inputs.** Update the variable/object type and implement semantic validations, including the Central US restriction and approved SKU/tier rules.
3. **Create the module.** Add resources under `modules/<service-name>/`; keep implementation out of the root where practical.
4. **Wire the module.** Update root orchestration and outputs only as needed. Preserve existing JSON behavior.
5. **Add a minimal example.** Show the smallest valid configuration and an optional/disabled configuration if supported.
6. **Add positive and negative tests.** Test valid input, invalid SKU/tier, invalid name, forbidden region, omitted optional service, and dependency-specific rules as applicable.
7. **Update governance.** Add or update Azure Policy definitions where server-side enforcement is required. Document who assigns them and at what scope.
8. **Update docs and diagrams.** Describe the service, defaults, risks, outputs, and onboarding steps.
9. **Run checks locally.** Format, initialize without backend where applicable, validate, test, parse JSON, and inspect the plan in a safe non-production environment.
10. **Request review.** A platform reviewer and the relevant security/governance owner must approve changes to global restrictions or security defaults.
11. **Verify CI.** Do not merge based only on a successful local run. Confirm required GitHub Actions checks passed.

### Definition of done

- The end-user JSON remains understandable and documented.
- Schema and VS Code completion work for the new fields.
- Terraform rejects invalid values with actionable error messages.
- Tests cover both accepted and rejected configurations.
- Applicable Azure Policy and RBAC controls are documented and deployed through an approved governance process.
- Existing examples and tests still pass.
- The plan has been reviewed and the CI checks are green.

## 9. Environment and state strategy

- Prefer separate Azure subscriptions for Dev, QA, Staging, and Production.
- Use a separate state key/backend boundary per environment. Never share one state file across environments.
- Store state in a secured Azure Storage backend with encryption, restricted access, and state locking.
- Keep state and plan files out of Git.
- Use GitHub Actions OIDC/workload federation rather than long-lived client secrets where possible.
- Use a low-privilege plan identity and a separately authorized apply identity.
- Protect the production environment with branch protection, environment approvals, and restricted deployment permissions.
- Use explicit environment-to-subscription mapping. Do not trust a user-provided subscription ID alone to authorize deployment.
- Promote reviewed code and module versions between environments; vary only approved environment inputs and identities.
- Before apply, inspect changes for deletes, replacements, public exposure, and cost impact.

## 10. CI/CD requirements

The validation workflow should run on pull requests and relevant pushes and should include:
1. Terraform formatting check.
2. Initialization without a backend for static validation.
3. Terraform validation.
4. JSON syntax and schema checks for every example.
5. Terraform tests using mocked providers where supported.
6. Policy JSON syntax checks.
7. Security scanning and provider/module checks as the project matures.

A deployment workflow should be separate from validation. It should use protected environments, trusted identities, explicit input files, a reviewed plan, and an approved apply step. Do not automatically apply unreviewed pull-request code or deploy to production from arbitrary branches.

Pin third-party GitHub Actions to reviewed immutable commit SHAs before treating the workflow as production hardened.

## 11. Toolchain and provider version policy

- Terraform CLI minimum supported version is `1.16.6`; CI pins `1.16.6` so pull requests run against a predictable version. Keep the CLI requirement and CI pin aligned.
- Use the latest stable release for upgrades, not alpha, beta, or release-candidate builds. Review release notes and test the configuration before changing the pin.
- The AzureRM provider is pinned to `5.9.0` in `versions.tf`. This is a major upgrade from 4.x and must be reviewed and tested against the official AzureRM 5.0 upgrade guide before applying to existing state.
- AzureRM 5.x no longer registers resource providers by default. This platform requests `Microsoft.Resources` and `Microsoft.Network`; deployment identities need registration permissions unless registration is managed centrally.
- Commit `.terraform.lock.hcl` after successful initialization on supported platforms.
- Commit the Terraform dependency lock file (`.terraform.lock.hcl`) after a successful `terraform init` on supported platforms. Review provider checksum changes as part of dependency upgrades.
- Upgrade procedure: review the major-version migration guide, update the provider pin and lock file together, initialize with the intended version, run formatting, validation, tests, and a non-production plan, then verify GitHub Actions before merging. Do not claim the upgrade is complete until CI passes.

## 12. Versioning and change management

Treat the JSON configuration and module interfaces as APIs:
- **Patch:** documentation, test additions, or compatible bug fixes.
- **Minor:** additive optional fields or new service types with safe defaults.
- **Major:** renamed/removed fields, changed meanings, tighter restrictions that invalidate previously valid input, or breaking output changes.

For breaking changes, document old and new JSON examples, migration steps, rollback considerations, and a deprecation period where feasible. Record significant architecture choices in `docs/decisions/` with context, decision, alternatives, and consequences.

## 13. Operations, observability and lifecycle

For each service, define how operators discover resource IDs, monitor health, retrieve diagnostics, rotate secrets, recover data, and retire resources. Prefer explicit outputs for IDs and endpoints, but do not output secret material. Add diagnostics and alerting defaults where required by platform standards.

Resource deletion must be deliberate. Document whether deletion is reversible, whether data can be lost, and how backups or retention policies apply. Consider Azure resource locks for critical shared or production resources, while ensuring the lifecycle workflow accounts for them.

## 14. Current implementation vs. planned capability

The existing repository implements JSON-driven resource groups, optional virtual networks and subnets, a VS Code JSON Schema, basic naming/CIDR validation, tests, and example Azure Policy definitions. Other service modules, full multi-environment deployment automation, remote state, OIDC deployment, and policy assignments must be treated as future work until implemented and verified.

Do not describe a restriction as “enforced” solely because it appears in this document or a schema. Confirm the corresponding Terraform validation, automated test, Azure Policy assignment, RBAC control, or deployment gate actually exists.

## 15. Suggested implementation roadmap

**Phase 1 — Stabilize the contract**
- Keep the current resource-group/VNet/subnet behavior.
- Add schema validation to CI and test invalid JSON examples.
- Confirm all current tests and formatting checks pass.

**Phase 2 — Modularize current services**
- Extract resource-group, VNet, and subnet implementations into clear module boundaries where justified.
- Preserve the public JSON input contract and verify plans before/after refactoring.

**Phase 3 — Add one service at a time**
- Choose a low-risk service, such as a storage account with secure defaults.
- Implement schema, module, allowlists, validations, tests, policy review, docs, and examples together.

**Phase 4 — Harden deployment**
- Add remote state, OIDC, least-privilege identities, environment protection, plan review, and explicit environment-to-subscription mapping.
- Assign reviewed Azure Policies at the correct scopes.

**Phase 5 — Scale governance**
- Add automated security checks, cost controls, drift detection, operational monitoring, module versioning, and a service catalog as needed.

## 16. Developer quick reference

Before opening a PR, ask:
- Does the JSON describe intent rather than Terraform internals?
- Does VS Code explain each field?
- Are defaults secure, and is Central US still enforced?
- Are naming, SKU/tier, tag, networking, and identity rules explicit?
- Are valid and invalid inputs tested?
- Is server-side policy required, and is it actually assigned?
- Are state, credentials and plan files protected?
- Is the deployment reviewed, environment-scoped and least-privileged?
- Are the README and diagrams accurate to what is implemented?

If any answer is unknown, document the gap and resolve it before claiming production readiness.
