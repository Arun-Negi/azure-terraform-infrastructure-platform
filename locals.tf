locals {
  # Region is a platform guardrail; users cannot override it in JSON.
  azure_location = "centralus"

  allowed_generated_name_pattern = "^[a-z0-9]+(-[a-z0-9]+)*$"

  # Every supported resource type uses the shared naming module.
  # Azure name limits: resource group 90, VNet 64, subnet 80.
  naming_requests = merge(
    {
      for rg in var.resource_groups : "rg-${rg.instance}" => {
        type_code       = "rg"
        instance        = rg.instance
        max_length      = 90
        allowed_pattern = local.allowed_generated_name_pattern
      }
    },
    {
      for rg in var.resource_groups : "vnet-${rg.instance}" => {
        type_code       = "vnet"
        instance        = rg.virtual_network.instance
        max_length      = 64
        allowed_pattern = local.allowed_generated_name_pattern
      } if rg.virtual_network != null
    },
    {
      for item in flatten([
        for rg in var.resource_groups : [
          for subnet in try(rg.virtual_network.subnets, []) : {
            key      = "snet-${rg.instance}-${subnet.instance}"
            instance = subnet.instance
          }
        ]
      ]) : item.key => {
        type_code       = "snet"
        instance        = item.instance
        max_length      = 80
        allowed_pattern = local.allowed_generated_name_pattern
      }
    }
  )

  resource_groups = {
    for rg in var.resource_groups :
    rg.instance => merge(rg, {
      name = module.naming.names["rg-${rg.instance}"]
    })
  }

  subnet_entries = flatten([
    for rg_key, rg in local.resource_groups : [
      for subnet in try(rg.virtual_network.subnets, []) : {
        key              = "snet-${rg_key}-${subnet.instance}"
        rg_key           = rg_key
        name             = module.naming.names["snet-${rg_key}-${subnet.instance}"]
        address_prefixes = subnet.address_prefixes
      }
    ]
  ])

  subnets = {
    for subnet in local.subnet_entries : subnet.key => subnet
  }
}
