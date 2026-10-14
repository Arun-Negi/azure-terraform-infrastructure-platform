module "naming" {
  source   = "./modules/naming"
  org      = var.naming.org
  app      = var.naming.app
  env      = var.naming.env
  resources = local.naming_requests
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_groups

  name     = each.value.name
  location = local.azure_location
  tags     = each.value.tags
}

resource "azurerm_virtual_network" "this" {
  for_each = {
    for key, rg in local.resource_groups : key => rg
    if rg.virtual_network != null
  }

  name                = module.naming.names["vnet-${each.key}"]
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  address_space       = each.value.virtual_network.address_space
  tags                = each.value.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.this[each.value.rg_key].name
  virtual_network_name = azurerm_virtual_network.this[each.value.rg_key].name
  address_prefixes     = each.value.address_prefixes
}
