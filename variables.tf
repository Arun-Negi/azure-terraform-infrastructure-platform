variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "resource_groups" {
  description = "Simple JSON list of resource groups. Location is centrally fixed to Central US."
  type        = list(object({
    name            = string
    tags            = optional(map(string), {})
    virtual_network = optional(object({
      name          = string
      address_space = list(string)
      subnets       = optional(list(object({
        name             = string
        address_prefixes = list(string)
      })), [])
    }), null)
  }))
  nullable = false

  validation {
    condition     = length(var.resource_groups) > 0
    error_message = "Provide at least one resource group in the JSON input."
  }

  validation {
    condition = alltrue([
      for rg in var.resource_groups :
      length(rg.name) >= 1 &&
      length(rg.name) <= 90 &&
      can(regex("^[A-Za-z0-9_().-]+$", rg.name)) &&
      !endswith(rg.name, ".")
    ])
    error_message = "Resource group names must be 1-90 characters, use only letters, numbers, underscore, parentheses, hyphen or period, and must not end with a period."
  }

  validation {
    condition = length(distinct([
      for rg in var.resource_groups : lower(rg.name)
    ])) == length(var.resource_groups)
    error_message = "Resource group names must be unique case-insensitively."
  }

  validation {
    condition = alltrue([
      for rg in var.resource_groups : rg.virtual_network == null ? true : (
        length(rg.virtual_network.name) >= 2 &&
        length(rg.virtual_network.name) <= 64 &&
        can(regex("^[A-Za-z0-9_.-]+$", rg.virtual_network.name)) &&
        length(rg.virtual_network.address_space) > 0 &&
        alltrue([for prefix in rg.virtual_network.address_space : can(cidrhost(prefix, 0))]) &&
        length(distinct([for subnet in rg.virtual_network.subnets : lower(subnet.name)])) == length(rg.virtual_network.subnets) &&
        alltrue([
          for subnet in rg.virtual_network.subnets :
          length(subnet.name) >= 1 &&
          length(subnet.name) <= 80 &&
          can(regex("^[A-Za-z0-9_.-]+$", subnet.name)) &&
          length(subnet.address_prefixes) > 0 &&
          alltrue([for prefix in subnet.address_prefixes : can(cidrhost(prefix, 0))])
        ])
      )
    ])
    error_message = "Check VNet/subnet names, unique subnet names, and valid non-empty CIDR address ranges."
  }
}
