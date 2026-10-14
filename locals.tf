locals {
  # Safely flatten resource-group -> optional VNet -> subnet inventory.
  # try() makes groups without a VNet contribute an empty subnet map.
  subnet_entries = flatten([
    for rg_key, rg in var.resource_groups : [
      for subnet_key, subnet in try(rg.virtual_network.subnets, {}) : {
        key              = "${rg_key}/${subnet_key}"
        rg_key           = rg_key
        subnet_key       = subnet_key
        name             = subnet.name
        address_prefixes = subnet.address_prefixes
      }
    ]
  ])

  subnets = {
    for subnet in local.subnet_entries : subnet.key => subnet
  }
}
