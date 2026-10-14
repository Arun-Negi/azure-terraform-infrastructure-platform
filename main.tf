locals {
  subnet_entries = flatten([
    for rg_key, rg in var.resource_groups : [
      for subnet_key, subnet in rg.virtual_network.subnets : {
        key              = "${rg_key}/${subnet_key}"
        rg_key            = rg_key
        subnet_key        = subnet_key
        name              = subnet.name
        address_prefixes  = subnet.address_prefixes
      }
    ] if rg.virtual_network != null
  ])

  subnets = {
    for subnet in local.subnet_entries : subnet.key => subnet
  }
}

resource "azurerm_resource_group" "this" {
  for_each = var.resource_groups

  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags
}

resource "azurerm_virtual_network" "this" {
  for_each = {
    for key, rg in var.resource_groups : key => rg
    if rg.virtual_network != null
  }

  name                = each.value.virtual_network.name
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
