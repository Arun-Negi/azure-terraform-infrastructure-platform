# Azure Terraform Infrastructure Platform

A scalable, configuration-driven Terraform root module for deploying **N resource groups in one run**, with optional virtual networks and multiple subnets per resource group. The desired infrastructure is declared as data in a map; Terraform expands resources with `for_each`, so adding resource groups does not require copying resource blocks.

## Capabilities

- Create any number of resource groups in one plan/apply.
- Optionally create one VNet and multiple subnets for each resource group.
- Apply tags to resource groups and VNets.
- Fail early for missing/empty input, invalid resource-group name characters/length, trailing-period resource-group names, case-insensitive duplicate RG names, and malformed network input structure.
- Run Terraform formatting and configuration validation in GitHub Actions.
- Keep the design extensible for additional Azure resource types and policy checks.

## Repository layout

- `versions.tf`: Terraform and AzureRM provider constraints.
- `variables.tf`: typed inventory input and custom validations.
- `main.tf`: map-driven resource creation using `for_each`.
- `outputs.tf`: resource IDs and names.
- `terraform.tfvars.example`: two resource groups, one VNet, and multiple subnets.
- `.github/workflows/terraform-validate.yml`: CI formatting and validation.

## Deploy N resource groups in one run

1. Install Terraform 1.6+ and Azure CLI.
2. Authenticate to Azure with your approved identity and select the target subscription.
3. Copy `terraform.tfvars.example` to `terraform.tfvars`; set the actual subscription ID and desired inventory.
4. Add or remove entries under `resource_groups`. Each entry creates one resource group. Include `virtual_network` only for groups that need a VNet.
5. Run:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Review the plan before applying. Use a secure remote backend for team/CI use; never commit state files or real `.tfvars` files.

## Scaling pattern

The input is a map keyed by a stable logical identifier:

```hcl
resource_groups = {
  app_dev = {
    name     = "rg-app-dev-eastus"
    location = "eastus"
    tags     = { environment = "dev", managed_by = "terraform" }
  }
  data_dev = {
    name     = "rg-data-dev-eastus"
    location = "eastus"
    tags     = { environment = "dev", managed_by = "terraform" }
  }
}
```

Add as many entries as required. A map key should be stable over time because changing a key changes the Terraform resource address. For large inventories, generate a reviewed `.tfvars` file from YAML/JSON rather than duplicating HCL blocks.

## Azure rules, ARM schemas, and validation boundaries

There is no single ARM schema that contains every live Azure restriction for every resource. ARM template schemas describe template structure; each resource provider and API version also has its own contract, and some rules depend on the live subscription or tenant.

This project uses several validation layers:

1. **Terraform type constraints and custom validations** catch errors that this module can determine locally. Resource-group name validation follows the documented 1–90 character limit and allowed character set, including the no-trailing-period rule.
2. **AzureRM provider schema and validation** checks supported arguments, types, and many resource-specific constraints.
3. **Azure Resource Manager/resource providers** are authoritative for API-level rules, supported locations, quota, provider registration, RBAC, Azure Policy, uniqueness in the live scope, and conflicts with existing resources.
4. **Azure Policy** should enforce organization-wide rules such as allowed regions, mandatory tags, approved SKUs, private networking, and public-access restrictions.

A successful `terraform validate` does not guarantee an Azure deployment will succeed. We deliberately do not claim that a handful of custom regexes replicate every ARM/OpenAPI rule. If strict schema conformance is a requirement, add versioned schema-driven tests for each supported resource type/API version and pin the provider versions those tests target.

### Recommended hardening before production

- Commit `.terraform.lock.hcl` after initializing with the intended provider version.
- Configure an Azure Storage remote backend with private access, RBAC, and state locking.
- Use GitHub Actions OIDC instead of client secrets; split plan and apply identities and scope them least-privilege.
- Protect production with required reviewers and apply the exact reviewed plan.
- Add `tflint`, Checkov or Trivy, unit tests, integration tests, and scheduled drift reporting.
- Add Azure Policy assignments for constraints that should be centrally enforced.
- Test invalid names, duplicate names, bad locations, subnet overlaps, denied SKUs, and policy violations in a non-production subscription.

## Important boundaries

- The caller must have permissions to create the requested resources in the selected subscription.
- CI currently runs formatting and static Terraform validation only; it does not authenticate to Azure or deploy resources.
- Changing/removing a resource-group map key or inventory entry can replace or destroy infrastructure. Review plans carefully.
- Azure resources can incur charges. Destroy test resources only after verifying the selected subscription and plan.
