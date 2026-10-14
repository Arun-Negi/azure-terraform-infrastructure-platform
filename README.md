# Azure Terraform Infrastructure Platform

A portfolio project demonstrating reusable Terraform modules, environment isolation, remote state, GitHub Actions, Azure OIDC authentication, and controlled production deployments.

> This is a starter implementation. Review the code and cost/security settings for your subscription before applying it.

## Architecture

- `modules/resource_group`: reusable resource group
- `modules/network`: reusable VNet, subnet, and network security group
- `environments/dev`, `staging`, `prod`: independent root modules and variable files
- `.github/workflows`: pull-request validation/plan and manually approved apply
- Azure Blob Storage backend: remote state with Azure Blob lease-based state locking
- GitHub Actions OIDC: short-lived Azure credentials; no client secret stored in GitHub

## Prerequisites

- Azure subscription and permission to create resource groups, VNets, NSGs, Log Analytics workspaces, and a storage account for state
- Terraform >= 1.6
- Azure CLI (`az`) and Git
- GitHub repository with Actions enabled

## 1. Bootstrap the Terraform state backend (one-time)

State storage must exist before Terraform can use it as a backend. Use a separate, tightly controlled bootstrap step. Example commands (choose a globally unique storage account name; names are lowercase letters/numbers, 3–24 characters):

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az group create --name rg-tfstate-platform --location centralindia
az storage account create \
  --name "<UNIQUE_STORAGE_ACCOUNT_NAME>" \
  --resource-group rg-tfstate-platform \
  --location centralindia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
az storage container create \
  --name tfstate \
  --account-name "<UNIQUE_STORAGE_ACCOUNT_NAME>" \
  --auth-mode login
```

Enable storage account infrastructure encryption and appropriate network restrictions for a real production deployment. Grant the identity running Terraform the minimum required data-plane role, commonly **Storage Blob Data Contributor** scoped to the state container. Do not commit credentials or state files.

Update `backend.hcl.example` with your storage account name and copy it to a local `backend.hcl` (ignored by Git). Then initialize one environment at a time:

```bash
cp backend.hcl.example backend.hcl
# Edit backend.hcl and set the real storage account name.
terraform -chdir=environments/dev init -backend-config=../../backend.hcl
terraform -chdir=environments/dev plan -var-file=dev.tfvars
```

Repeat for `staging` and `prod`. Each environment uses a distinct state key. Never point two environments at the same key.

## 2. Configure GitHub OIDC for Azure

Create an Entra ID app registration/service principal and federated credential that trusts your GitHub repository. Use the exact owner/repository and branch/environment subject. Prefer separate identities and least-privilege scopes for plan and apply, especially for production.

Set these GitHub **Actions variables** (identifiers, not credentials):
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TFSTATE_RESOURCE_GROUP`
- `AZURE_TFSTATE_STORAGE_ACCOUNT`
- `AZURE_TFSTATE_CONTAINER`

The PR workflow runs format and validation checks without Azure credentials. The manually triggered deployment workflow uses OIDC, initializes the remote backend, creates a plan, and applies it within the selected GitHub Environment. Configure required reviewers for `prod`. For a stricter enterprise workflow, split plan and apply into separate jobs and apply the exact reviewed plan artifact.

In the repository, go to **Settings → Environments** and create `dev`, `staging`, and `prod`. Add required reviewers to `prod`. Configure an Entra federated credential for each environment subject, for example:
`repo:OWNER/REPOSITORY:environment:prod`

The workflow uses `azure/login` with OIDC. No Azure client secret is needed. Ensure the service principal has only the permissions required by the resources being deployed and by the state backend.

## 3. GitHub Actions setup

1. Push this repository to GitHub.
2. Configure the variables and Azure federated credentials described above.
3. Create the GitHub environments: `dev`, `staging`, `prod`.
4. Open a pull request. Validation and a plan should run for the dev root.
5. Merge after review. Use **Actions → Terraform Apply → Run workflow** and choose the environment. Production should require an environment reviewer.
6. Review the plan before applying. This starter deliberately does not auto-apply on pull requests.

## 4. Local workflow

```bash
terraform -chdir=environments/dev fmt -recursive
terraform -chdir=environments/dev init -backend-config=../../backend.hcl
terraform -chdir=environments/dev validate
terraform -chdir=environments/dev plan -var-file=dev.tfvars
```

Apply only after reviewing the plan:

```bash
terraform -chdir=environments/dev apply -var-file=dev.tfvars
```

Destroy resources when you are done testing, after checking the selected subscription and environment:

```bash
terraform -chdir=environments/dev destroy -var-file=dev.tfvars
```

## 5. Environment design

Each environment is an independent Terraform root module and uses its own state key:
- `platform/dev.tfstate`
- `platform/staging.tfstate`
- `platform/prod.tfstate`

The initial workflow demonstrates PR validation and manual apply. Extend it with environment-specific plans, policy checks, drift detection on a schedule, and separate plan/apply identities before calling it production-ready.

## 6. Suggested next improvements

- Add `tflint` and Checkov or Trivy configuration scanning.
- Add Azure Policy / policy-as-code checks.
- Add scheduled drift detection that reports changes but does not automatically apply them.
- Add unit/integration tests and module versioning.
- Add diagnostic settings, private endpoints, and state-storage network restrictions.
- Document an architecture decision record, failure scenarios, and cost estimate.

## Cleanup and cost

Azure resources may incur charges. Run `terraform destroy` for each environment when finished, and separately remove the state storage only after confirming no state is needed. Keep the state backend until all managed environments have been safely removed.
