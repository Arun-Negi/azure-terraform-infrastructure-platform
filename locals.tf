locals {
  # Keep region policy in one place so end users do not need to repeat it.
  azure_location = "centralus"

  # Use the resource group name as the stable Terraform key.
  resource_groups = {
    for rg in var.resource_groups : rg.name => rg
  }

  subnet_entries = flatten([
    for rg_key, rg in local.resource_groups : [
      for subnet in try(rg.virtual_network.subnets, []) : {
        key              = "${rg_key}/${subnet.name}"
        rg_key           = rg_key
        name             = subnet.name
        address_prefixes = subnet.address_prefixes
      }
    ]
  ])

  subnets = {
    for subnet in local.subnet_entries : subnet.key => subnet
  }
}
