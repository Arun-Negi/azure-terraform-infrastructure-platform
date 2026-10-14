output "resource_groups" {
  description = "Created resource groups keyed by the input map key."
  value = {
    for key, rg in azurerm_resource_group.this : key => {
      id       = rg.id
      name     = rg.name
      location = rg.location
    }
  }
}

output "virtual_networks" {
  description = "Created virtual networks keyed by the resource group input key."
  value = {
    for key, vnet in azurerm_virtual_network.this : key => {
      id   = vnet.id
      name = vnet.name
    }
  }
}

output "subnets" {
  description = "Created subnets keyed by resource-group-key/subnet-key."
  value = {
    for key, subnet in azurerm_subnet.this : key => {
      id   = subnet.id
      name = subnet.name
    }
  }
}
