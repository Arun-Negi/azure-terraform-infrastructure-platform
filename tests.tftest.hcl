# These tests use a mocked AzureRM provider. They validate configuration logic
# without Azure credentials, creating resources, or incurring cloud costs.
mock_provider "azurerm" {}

run "accepts_multiple_resource_groups_and_optional_vnet" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    resource_groups = {
      app = {
        name     = "rg-app-centralus"
        location = "centralus"
        tags     = { managed_by = "terraform", environment = "test" }
        virtual_network = {
          name          = "vnet-app"
          address_space = ["10.20.0.0/16"]
          subnets = {
            web = {
              name             = "snet-web"
              address_prefixes = ["10.20.1.0/24"]
            }
            data = {
              name             = "snet-data"
              address_prefixes = ["10.20.2.0/24"]
            }
          }
        }
      }
      shared = {
        name     = "rg-shared-centralus"
        location = "centralus"
      }
    }
  }

  assert {
    condition     = length(azurerm_resource_group.this) == 2
    error_message = "Two inventory entries must produce two resource groups."
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

run "rejects_non_centralus_location" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    resource_groups = {
      invalid = {
        name     = "rg-invalid"
        location = "eastus"
      }
    }
  }

  expect_failures = [var.resource_groups]
}

run "rejects_duplicate_resource_group_names_case_insensitively" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    resource_groups = {
      first  = { name = "rg-duplicate", location = "centralus" }
      second = { name = "RG-DUPLICATE", location = "centralus" }
    }
  }

  expect_failures = [var.resource_groups]
}

run "rejects_invalid_subnet_cidr" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    resource_groups = {
      app = {
        name     = "rg-app"
        location = "centralus"
        virtual_network = {
          name          = "vnet-app"
          address_space = ["10.30.0.0/16"]
          subnets = {
            bad = {
              name             = "snet-bad"
              address_prefixes = ["not-a-cidr"]
            }
          }
        }
      }
    }
  }

  expect_failures = [var.resource_groups]
}
