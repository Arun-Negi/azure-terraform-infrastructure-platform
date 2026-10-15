# Offline tests using a mocked AzureRM provider.
mock_provider "azurerm" {}

run "accepts_json_style_inventory_with_optional_networking" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    org             = "acme"
    app             = "platform"
    env             = "dev"
    resource_groups = [
      {
        instance = "core"
        tags     = { managed_by = "terraform", environment = "test" }
        virtual_network = {
          instance      = "main"
          address_space = ["10.20.0.0/16"]
          subnets = [
            { instance = "web", address_prefixes = ["10.20.1.0/24"] },
            { instance = "data", address_prefixes = ["10.20.2.0/24"] }
          ]
        }
      },
      {
        instance = "shared"
      }
    ]
  }

  assert {
    condition     = length(azurerm_resource_group.this) == 2
    error_message = "Two JSON resource group entries must produce two resource groups."
  }

  assert {
    condition     = length(azurerm_virtual_network.this) == 1
    error_message = "Only the group with a virtual_network object should produce a VNet."
  }

  assert {
    condition     = length(azurerm_subnet.this) == 2
    error_message = "The VNet's two subnet entries must produce two subnets."
  }
}

run "rejects_duplicate_resource_group_instances" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    org             = "acme"
    app             = "platform"
    env             = "dev"
    resource_groups = [
      { instance = "duplicate" },
      { instance = "duplicate" }
    ]
  }

  expect_failures = [var.resource_groups]
}

run "rejects_invalid_subnet_cidr" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    org             = "acme"
    app             = "platform"
    env             = "dev"
    resource_groups = [
      {
        instance = "app"
        virtual_network = {
          instance      = "main"
          address_space = ["10.30.0.0/16"]
          subnets = [
            { instance = "bad", address_prefixes = ["not-a-cidr"] }
          ]
        }
      }
    ]
  }

  expect_failures = [var.resource_groups]
}

run "rejects_generated_vnet_name_over_64_characters" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    org             = "acme"
    app             = "applicationname"
    env             = "prod"
    resource_groups = [
      {
        instance = "core"
        virtual_network = {
          instance      = "averylongnetworkinstanceidentifier123456"
          address_space = ["10.40.0.0/16"]
        }
      }
    ]
  }

  expect_failures = [output.generated_resource_names]
}


run "creates_storage_account_with_secure_defaults" {
  command = plan
  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    org             = "acme"
    app             = "platform"
    env             = "dev"
    resource_groups = [{ instance = "core", tags = { managed_by = "terraform" } }]
    storage_accounts = [{
      instance                = "logs001"
      resource_group_instance = "core"
    }]
  }
  assert {
    condition     = length(module.storage_account) == 1
    error_message = "One storage account JSON entry must produce one storage account module instance."
  }
  assert {
    condition     = module.storage_account["logs001"].name == "acmeplatformdevstlogs001"
    error_message = "Storage account names must be compact, lowercase, and generated through the shared naming module."
  }
}

run "rejects_invalid_storage_replication_type" {
  command = plan
  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    org             = "acme"
    app             = "platform"
    env             = "dev"
    resource_groups = [{ instance = "core" }]
    storage_accounts = [{
      instance                = "logs001"
      resource_group_instance = "core"
      replication_type        = "Premium_LRS"
    }]
  }
  expect_failures = [var.storage_accounts]
}
