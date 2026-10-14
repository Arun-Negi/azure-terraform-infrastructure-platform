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

## Validation and governance

Terraform validates resource group names, duplicate names, VNet/subnet names, and CIDR syntax before deployment. GitHub Actions checks Terraform formatting, JSON syntax, configuration validation, and offline Terraform tests with a mocked AzureRM provider. These checks do not deploy resources or guarantee Azure will accept a live request.

The `policies/azure-policy/` directory contains custom policy definitions for allowed locations and the `managed_by` tag. They are not assigned automatically; an authorized Azure administrator must review and assign them at the appropriate scope.

## Production hardening

- Configure an Azure Storage remote backend with restricted access and state locking.
- Use GitHub Actions OIDC and separate least-privilege plan/apply identities.
- Pin GitHub Actions to immutable commit SHAs.
- Test in a non-production subscription and inspect every plan; resource removals may destroy infrastructure.
- Azure resources can incur charges. Confirm the subscription and plan before applying or destroying.
