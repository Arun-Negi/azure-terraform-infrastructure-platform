# Azure Terraform Infrastructure Platform

Deploy Azure resource groups, optional virtual networks, and subnets by editing **one JSON file**. End users do not need to edit Terraform variables or HCL.

## Configure one JSON file

Copy the example to the automatically loaded Terraform input filename:

```bash
cp terraform.tfvars.json.example terraform.tfvars.json
```

Open `terraform.tfvars.json` and change the subscription ID, resource group names, tags, and optional network details. The example below creates two resource groups, one VNet, and two subnets:

```json
{
  "subscription_id": "00000000-0000-0000-0000-000000000000",
  "resource_groups": [
    {
      "name": "rg-platform-dev-centralus",
      "tags": {
        "environment": "dev",
        "managed_by": "terraform"
      },
      "virtual_network": {
        "name": "vnet-platform-dev",
        "address_space": ["10.10.0.0/16"],
        "subnets": [
          {
            "name": "snet-app",
            "address_prefixes": ["10.10.1.0/24"]
          },
          {
            "name": "snet-data",
            "address_prefixes": ["10.10.2.0/24"]
          }
        ]
      }
    },
    {
      "name": "rg-shared-monitoring-centralus",
      "tags": {
        "environment": "shared",
        "managed_by": "terraform"
      }
    }
  ]
}
```

### The only fields to remember

- `subscription_id`: the Azure subscription GUID.
- `resource_groups`: a JSON array; each object creates one resource group.
- `name`: the Azure resource name.
- `tags` (optional): key/value tags.
- `virtual_network` (optional): add this object only when that group needs a VNet.
- `address_space`: VNet CIDR range(s).
- `subnets` (optional): a JSON array of subnet objects. Each subnet has a name and CIDR prefix list.
- **Location is fixed to Central US** (`centralus`) in Terraform, so users do not need to repeat it for every resource group.

To add resources, add objects to the appropriate JSON array. To omit networking for a resource group, omit its `virtual_network` property. Keep resource names stable between applies; renaming or removing resources can cause Terraform to replace or destroy infrastructure.

### VS Code JSON IntelliSense

The repository includes a JSON Schema at `schemas/terraform-input.schema.json` and a workspace setting at `.vscode/settings.json`. When you open this repository in VS Code and edit `terraform.tfvars.json`, IntelliSense provides field suggestions, descriptions, and basic validation for required fields, names, and CIDR formatting.

1. Open the repository folder in VS Code (not just the JSON file by itself).
2. Copy the example: `cp terraform.tfvars.json.example terraform.tfvars.json`.
3. Open `terraform.tfvars.json` and place the cursor inside an object to see suggestions; hover over a property to read its description.
4. Follow the schema hints, then run `terraform validate` and `terraform plan` before applying.

The schema catches common input mistakes in the editor, but it cannot validate every Azure rule (such as CIDR overlap, whether a subnet fits inside its VNet, or whether a name already exists in Azure). Terraform validation and the Azure provider remain authoritative.

## Deploy

1. Install Terraform 1.6+ and Azure CLI.
2. Authenticate using your approved Azure identity and confirm the target subscription.
3. Copy and edit the JSON input file as described above.
4. Run:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Review the plan before applying. The sample subscription ID is a placeholder and must be replaced. Never commit real input files, Terraform state, or secrets. Use a secure remote backend and least-privilege identity for team/CI use.

## Developer design standard

For the rules and workflow for adding Azure services while preserving the JSON-only user experience, shared restrictions, testing, environment separation, and deployment controls, see the [Developer Design Standard](docs/DESIGN-STANDARD.md).

## Validation and governance

Terraform validates resource group names, duplicate names, VNet/subnet names, and CIDR syntax before deployment. GitHub Actions checks Terraform formatting, JSON syntax, configuration validation, and offline Terraform tests with a mocked AzureRM provider. These checks do not deploy resources or guarantee Azure will accept a live request.

The `policies/azure-policy/` directory contains custom policy definitions for allowed locations and the `managed_by` tag. They are not assigned automatically; an authorized Azure administrator must review and assign them at the appropriate scope.

## Production hardening

- Configure an Azure Storage remote backend with restricted access and state locking.
- Use GitHub Actions OIDC and separate least-privilege plan/apply identities.
- Pin GitHub Actions to immutable commit SHAs.
- Test in a non-production subscription and inspect every plan; resource removals may destroy infrastructure.
- Azure resources can incur charges. Confirm the subscription and plan before applying or destroying.
