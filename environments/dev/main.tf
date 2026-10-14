module "resource_group" {
  source   = "../../modules/resource_group"
  name     = "rg-platform-dev"
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source              = "../../modules/network"
  name                = "platform-dev"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
  tags                = local.common_tags
}

locals {
  common_tags = merge(var.tags, {
    environment = "dev"
    managed_by  = "terraform"
    project     = "azure-terraform-platform"
  })
}
