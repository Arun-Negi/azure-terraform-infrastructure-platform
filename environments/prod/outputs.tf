output "resource_group_name" {
  description = "Created resource group."
  value       = module.resource_group.name
}

output "vnet_id" {
  description = "Created virtual network."
  value       = module.network.vnet_id
}

output "workload_subnet_id" {
  description = "Created workload subnet."
  value       = module.network.subnet_id
}
