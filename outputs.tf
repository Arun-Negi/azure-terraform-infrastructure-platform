output "resource_groups" {
  description = "Created resource groups keyed by Azure resource group name."
  value = {
    for key, rg in azurerm_resource_group.this : key => {
      id       = rg.id
      name     = rg.name
      location = rg.location
    }
  }
}

output "virtual_networks" {
  description = "Created virtual networks keyed by Azure resource group name."
  value = {
    for key, vnet in azurerm_virtual_network.this : key => {
      id   = vnet.id
      name = vnet.name
    }
  }
}

output "subnets" {
  description = "Created subnets keyed by resource-group-name/subnet-name."
  value = {
    for key, subnet in azurerm_subnet.this : key => {
      id   = subnet.id
      name = subnet.name
    }
  }
}

output "generated_resource_names" {
  description = "All validated generated names, keyed by resource type and instance."
  value       = module.naming.names
}
