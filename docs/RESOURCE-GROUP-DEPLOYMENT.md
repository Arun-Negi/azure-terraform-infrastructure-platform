# Resource Group configuration and deployment

## Layout

Each independently managed logical Resource Group has its own directory:

- resource-groups/rg-dev-network/inputjson/resource-group.json
- resource-groups/rg-dev-network/inputjson/virtual-network.json
- resource-groups/rg-dev-network/inputjson/subnet.json
- resource-groups/rg-dev-storage/inputjson/resource-group.json
- resource-groups/rg-dev-storage/inputjson/storage-account.json
- resource-groups/rg-prod-app/inputjson/resource-group.json
- resource-groups/rg-prod-app/inputjson/virtual-network.json
- resource-groups/rg-prod-app/inputjson/storage-account.json

Reusable modules stay under modules/. Existing service schemas stay under schemas/services/. The per-file input contracts are under schemas/configuration/. Do not copy modules or schemas into Resource Group folders.

## File contracts

- resource-group.json is required and contains subscription_id, org, app, env, the Resource Group instance, and optional tags.
- virtual-network.json is optional and contains instance and address_space.
- subnet.json is optional, requires a sibling virtual-network.json, and contains a subnets array.
- storage-account.json is optional and contains a storage_accounts array. Each resource_group_instance must match the sibling Resource Group instance.
- Unsupported service files are rejected rather than silently ignored. Network Security Group input remains disabled until its Terraform module and validations exist.

The folder name is a stable pipeline selector, for example rg-dev-network. The instance field drives the existing naming module and is not inferred from the folder name. Keep instance values stable after deployment.

## Example Resource Group

    {
      "subscription_id": "00000000-0000-0000-0000-000000000000",
      "org": "acme",
      "app": "platform",
      "env": "dev",
      "instance": "network",
      "tags": { "environment": "dev", "managed_by": "terraform" }
    }

The assembler validates each file and converts it to the current Terraform root input contract. Existing typed Terraform validations and the centralized naming module remain in force.

## Validate locally

Use Python 3.12+ and Terraform 1.16.6:

    python -m pip install -r requirements-validation.txt
    python scripts/assemble_resource_group.py --input-dir resource-groups/rg-dev-network/inputjson --output /tmp/rg-dev-network.tfvars.json
    python scripts/assemble_resource_group.py --input-dir resource-groups/rg-dev-storage/inputjson --output /tmp/rg-dev-storage.tfvars.json
    terraform fmt -check -recursive
    terraform init -backend=false
    terraform validate

The generated variable file is a temporary build artifact; do not commit it. Validation of a manually selected folder does not require unrelated configuration folders to be valid.

## GitHub Actions

Open Actions → Resource Group isolated plan and apply → Run workflow. Enter one folder name such as rg-dev-network. The workflow validates only that folder and creates a plan using a state key derived from its folder name. Runs targeting the same folder are serialized; different folders may run in parallel.

Pull requests validate changed Resource Group folders. If no Resource Group folder changed, all configured folders are validated because shared Terraform/schema changes can affect each stack.

## Required backend and identity setup

The existing root did not declare a remote backend or an Azure deployment workflow. Before planning against Azure, configure repository variables:

- TF_STATE_RESOURCE_GROUP
- TF_STATE_STORAGE_ACCOUNT
- TF_STATE_CONTAINER

Configure repository secrets:

- ARM_CLIENT_ID
- ARM_TENANT_ID
- ARM_SUBSCRIPTION_ID

Configure an Azure federated identity for GitHub Actions OIDC with least privilege, and create a protected GitHub environment named azure-apply with required reviewers. The apply stage is also disabled unless repository variable ENABLE_ISOLATED_APPLY is explicitly set to true. Leave it unset until state migration and a reviewed non-production plan are complete.

The plan job never applies infrastructure. Apply requires a manual run against main, apply=true, the repository enable flag, and approval from the protected environment. A plan can propose creates if the isolated state has not been migrated; do not enable apply merely because a plan succeeded.

## State isolation and migration warning

The backend key is deterministic and unique per folder: resource-groups/<folder-name>/terraform.tfstate. Azure Storage provides state locking per key. Workflow concurrency also serializes deployments targeting the same folder.

The old root state, if one exists, is not automatically split or migrated. The old root could manage multiple Resource Groups and Storage Accounts together, and repository inspection did not find committed state or an existing backend declaration. Before enabling apply:

1. Back up the existing state securely and inventory all tracked resource addresses.
2. Map every resource to exactly one folder and one state key.
3. Test a reviewed state-splitting/import procedure against a non-production copy first. Do not run state rm, state push, import, or apply against production as part of this code change.
4. Confirm each isolated state contains the expected addresses and plans show no unexpected creates, replacements, or destroys.
5. Only then set ENABLE_ISOLATED_APPLY=true and configure the protected environment.

Do not run the old root workflow and isolated workflow against the same resources simultaneously. This change does not deploy infrastructure or modify state.

## Updating and deleting resources

Edit only the relevant service file under the target folder. Keep instance values stable when changing non-identity settings. Changing org, app, env, or instance changes generated names and may force replacement. Inspect the plan before applying.

To delete a resource, remove its declaration from that Resource Group's JSON and review the resulting plan. A Resource Group's resources are not managed by another folder's state. Deleting the Resource Group itself requires a deliberate configuration change and a reviewed destructive plan; data loss may be irreversible. Never apply a plan with unexpected destroys.

## Adding a Resource Group

1. Create resource-groups/rg-<env>-<purpose>/inputjson/.
2. Add resource-group.json with valid shared naming fields and a unique instance.
3. Add only the required service JSON files, one file per service type.
4. Reuse the service-specific schema under schemas/services/ and add a wrapper schema under schemas/configuration/ if needed.
5. Extend scripts/assemble_resource_group.py only after the service's Terraform implementation, schema, naming constraints, typed validation, and tests are ready.
6. Run local validation, inspect the generated input, and open a PR. Do not add unsupported resource declarations.

## Adding a new Azure service

Follow docs/DESIGN-STANDARD.md: service-specific schema, explicit Terraform module, centralized generated names, Azure-specific length/character/SKU/tier checks, safe defaults, cross-resource validation, positive and negative tests, and documentation. Never weaken existing rules to accommodate a new service.

## Implementation boundary

The assembler currently supports Resource Groups, virtual networks, subnets, and Storage Accounts. Network Security Group input is reserved but rejected until its module and checks are implemented. The root Terraform module remains the shared implementation; the selected JSON is reduced to exactly one Resource Group and its associated resources before planning. State isolation comes from the distinct backend key, not JSON filtering alone.
