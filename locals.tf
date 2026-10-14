locals {
  # Flatten the nested resource-group -> VNet -> subnet inventory into
  # one stable map for Terraform's for_each.
  subnet_entries = flatten([
    for rg_key, rg in var.resource_groups : [
      for subnet_key, subnet in rg.virtual_network.subnets : {
        key             = "${rg_key}/${subnet_key}"
        rg_key           = rg_key
        subnet_key       = subnet_key
        name              = subnet.name
        address_prefixes = subnet.address_prefixes
      }
    ] if rg.virtual_network != null
  ])

  subnets = {
    for subnet in local.subnet_entries : subnet.key => subnet
  }
}
