# Azure Terraform Infrastructure Platform

A scalable, configuration-driven Terraform root module for deploying multiple Azure resource groups in one run, with an optional virtual network and multiple subnets per group. The end user controls the inventory in `terraform.tfvars`; Terraform expands the map using `for_each`.

## What the end user controls

### How many resource groups?

The number of resource groups is the number of entries under `resource_groups`. For example, three entries create three resource groups. Add or remove entries to change the requested count. There is no hardcoded count in the Terraform resources; actual deployment size is still bounded by subscription quotas, API throttling, permissions, and operational considerations.

### How many other resources?

Each entry can optionally include a `virtual_network` object. If present, Terraform creates one VNet for that resource group. The number of subnets is the number of entries under that VNet's `subnets` map. This starter currently supports resource groups, VNets, and subnets; it does not yet model arbitrary Azure resource types, VM sizes, storage SKUs, or App Service tiers.

### How does the end user pass names?

The map key (such as `platform_dev`) is a stable Terraform identifier, not the Azure resource name. The `name` field is the actual Azure name. Keep map keys stable over time because changing a key changes the Terraform resource address and may cause replacement or recreation.

Example:

```hcl
subscription_id = "00000000-0000-0000-0000-000000000000"

resource_groups = {
  platform_dev = {
    name     = "rg-platform-dev-centralus"
    location = "centralus"
    tags = {
      environment = "dev"
      managed_by  = "terraform"
    }
    virtual_network = {
      name          = "vnet-platform-dev"
      address_space = ["10.10.0.0/16"]
      subnets = {
        app = {
          name             = "snet-app"
          address_prefixes = ["10.10.1.0/24"]
        }
        data = {
          name             = "snet-data"
          address_prefixes = ["10.10.2.0/24"]
        }
      }
    }
  }

  shared_monitoring = {
    name     = "rg-shared-monitoring-centralus"
    location = "centralus"
    tags     = { environment = "shared", managed_by = "terraform" }
  }
}
```

In this example there are two resource groups, one VNet, and two subnets. The second group has no `virtual_network`, so no VNet or subnet is created for it. To deploy 20 groups, define 20 entries. For large inventories, generate and review a `.tfvars` file from YAML/JSON rather than manually copying blocks.

## Current repository layout

- `versions.tf`: Terraform and AzureRM provider constraints.
- `variables.tf`: typed inventory plus input validations.
- `locals.tf`: derives a flattened subnet map from the nested inventory.
- `main.tf`: creates resource groups, VNets, and subnets using `for_each`.
- `outputs.tf`: IDs and names for created resources.
- `terraform.tfvars.example`: example inventory.
- `.github/workflows/terraform-validate.yml`: formatting, static validation, and configuration tests.
- `tests.tftest.hcl`: offline tests for resource scaling and invalid inputs.
- `policies/azure-policy/`: deployable custom Azure Policy definitions for allowed locations and required governance tags.

## Enforced rules in this version

- At least one resource group must be declared.
- Resource group names are 1-90 characters, use the configured allowed character set, and cannot end with a period.
- Resource group names are unique case-insensitively within this input.
- All resource groups must specify the Azure region identifier `centralus` (Central US).
- VNet names must be 2-64 characters and use letters, digits, periods, underscores, or hyphens.
- Subnet names must be 1-80 characters and use letters, digits, periods, underscores, or hyphens.
- Subnet names are unique case-insensitively within each VNet.
- VNet address spaces and subnet prefixes must be present and syntactically valid CIDRs.

These checks fail during Terraform validation/plan evaluation rather than waiting for the Azure create request. The custom rules intentionally apply to the resource types supported by this starter; different resource types need their own rule sets.

## Deploy

1. Install Terraform 1.6+ and Azure CLI.
2. Authenticate to Azure using your approved identity and confirm the target subscription.
3. Copy `terraform.tfvars.example` to `terraform.tfvars`, then set your actual subscription ID and inventory.
4. Run:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Always inspect the plan before applying. Use a secure remote backend for team/CI use; never commit state files or real `.tfvars` files.

## ARM schemas, provider schemas, SKUs, tiers, and Azure restrictions

Azure's naming rules vary by resource provider and resource type. SKU and tier values are also resource-specific: for example, storage accounts, virtual machines, databases, and App Service plans expose different properties and allowed values. The current resources (resource group, VNet, subnet) do not have a SKU/tier property, so there is no meaningful SKU/tier allowlist to enforce for them. When a new resource type is added, its own inputs and validation rules must be added.

A reliable layered approach is:

1. **Terraform type constraints and validations**: enforce fixed policy such as Central US, required tags, naming patterns, and inventory structure.
2. **AzureRM provider schema**: pin a provider version and use its typed resource arguments and provider-side validation for supported fields and enums.
3. **ARM resource-provider/API contract**: keep the exact resource type and API version explicit when using ARM/AzAPI. ARM template JSON schemas validate template structure, but they do not guarantee every live constraint (such as quota, RBAC, provider registration, conflicts, or policy) can be determined offline.
4. **Policy-as-code and Azure Policy**: use Checkov/OPA or equivalent for plan/config checks and Azure Policy for subscription-level rules such as allowed locations, approved SKUs, required tags, and public network access.
5. **Live preflight and tests**: test valid and invalid inputs in a non-production subscription; a successful `terraform validate` is not a guarantee that Azure will accept the deployment.

Official references:
- [Azure resource naming rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)
- [ARM template structure and schema](https://learn.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authoring-templates)
- [ARM template resource declaration](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/resource-declaration)
- [Microsoft.Resources/resourceGroups API reference](https://learn.microsoft.com/en-us/azure/templates/microsoft.resources/2021-01-01/resourcegroups)

### Schema-driven enhancement planned

For stronger schema coverage, the next phase should maintain a versioned inventory of supported resource types and API versions, generate or validate input contracts from the corresponding provider/API schemas, and add automated negative tests for each constraint. Keep schema-derived checks separate from organization policy (for example, Central US only) so that Azure service rules and company rules are not confused.

## Automated tests and Azure Policy

The CI workflow runs `terraform fmt`, `terraform validate`, and `terraform test`. The test suite uses a mocked AzureRM provider, so it checks Terraform configuration behavior without Azure credentials or deploying billable resources. It currently tests multiple resource groups, optional VNets, subnet scaling, Central US enforcement, duplicate resource-group names, and invalid subnet CIDRs.

Two custom Azure Policy definitions are included under `policies/azure-policy/`:
- `allowed-locations.json`: denies resource groups and VNets outside the configured allowlist (Central US by default).
- `require-managed-by-tag.json`: denies resource groups and VNets missing the `managed_by` tag by default.

These JSON files are policy definitions, not active subscription assignments. A subscription or management-group administrator must create and assign them at the appropriate scope; test the effect in audit mode or a non-production scope before enforcing deny. Azure Policy and Terraform input validation serve different purposes: local checks fail early, while assigned Azure Policy governs deployments across tools and identities.

The provider schema remains the authoritative typed contract for the AzureRM resources used here. This repository does not claim to automatically validate every Azure resource type or every live ARM constraint. To add a new resource type safely, pin the provider/API version, add its typed inputs and documented naming/enum validations, add negative tests, and add relevant Azure Policy rules. Azure can still reject requests because of quotas, RBAC, provider registration, existing-name conflicts, or other live conditions.

## Production hardening still required

- Initialize with the intended AzureRM provider version and commit `.terraform.lock.hcl`.
- Configure an Azure Storage remote backend with restricted access, RBAC, and state locking.
- Use GitHub Actions OIDC, separate least-privilege plan/apply identities, and protected production approvals.
- Pin GitHub Actions to immutable commit SHAs.
- Add tests for invalid names, duplicate names, invalid CIDRs, unsupported locations, denied SKUs, quotas, and Azure Policy violations.
- Review all plans before applying; removing inventory entries can destroy resources.
- Azure resources may incur charges. Confirm subscription and plan before applying or destroying.
