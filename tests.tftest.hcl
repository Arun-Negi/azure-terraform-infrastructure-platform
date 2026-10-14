# Offline tests using a mocked AzureRM provider.
mock_provider "azurerm" {}

run "accepts_json_style_inventory_with_optional_networking" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    resource_groups = [
      {
        name            = "rg-app-centralus"
        tags            = { managed_by = "terraform", environment = "test" }
        virtual_network = {
          name          = "vnet-app"
          address_space = ["10.20.0.0/16"]
          subnets       = [
            { name = "snet-web", address_prefixes = ["10.20.1.0/24"] },
            { name = "snet-data", address_prefixes = ["10.20.2.0/24"] }
          ]
        }
      },
      {
        name = "rg-shared-centralus"
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

run "rejects_duplicate_resource_group_names_case_insensitively" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    resource_groups = [
      { name = "rg-duplicate" },
      { name = "RG-DUPLICATE" }
    ]
  }

  expect_failures = [var.resource_groups]
}

run "rejects_invalid_subnet_cidr" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    resource_groups = [
      {
        name            = "rg-app"
        virtual_network = {
          name          = "vnet-app"
          address_space = ["10.30.0.0/16"]
          subnets = [
            { name = "snet-bad", address_prefixes = ["not-a-cidr"] }
          ]
        }
      }
    ]
  }

  expect_failures = [var.resource_groups]
}
