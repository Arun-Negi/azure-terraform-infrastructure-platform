terraform {
  required_version = ">= 1.16.6, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.9.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # AzureRM 5.x no longer automatically registers resource providers by default.
  # Register only the providers required by this platform.
  resource_providers_to_register = [
    "Microsoft.Resources",
    "Microsoft.Network",
    "Microsoft.Storage",
  ]
}
