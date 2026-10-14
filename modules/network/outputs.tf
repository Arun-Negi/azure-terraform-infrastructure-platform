output "vnet_id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "Workload subnet resource ID."
  value       = azurerm_subnet.workload.id
}

output "nsg_id" {
  description = "Workload network security group resource ID."
  value       = azurerm_network_security_group.workload.id
}
