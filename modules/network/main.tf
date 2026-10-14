resource "azurerm_virtual_network" "this" {
  name                = "${var.name}-vnet"
  address_space       = var.vnet_cidr
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "${var.name}-snet-workload"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_cidr
}

resource "azurerm_network_security_group" "workload" {
  name                = "${var.name}-nsg-workload"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
