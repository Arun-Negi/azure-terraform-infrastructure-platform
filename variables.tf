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
  description = "Map of resource groups to create. Each entry can optionally include a virtual network and subnets."
  type = map(object({
    name     = string
    location = string
    tags     = optional(map(string), {})
    virtual_network = optional(object({
      name          = string
      address_space = list(string)
      subnets = optional(map(object({
        name             = string
        address_prefixes = list(string)
      })), {})
    }), null)
  }))
  nullable = false

  validation {
    condition     = length(var.resource_groups) > 0
    error_message = "Provide at least one resource group."
  }

  validation {
    condition = alltrue([
      for rg in values(var.resource_groups) :
      length(rg.name) >= 1 &&
      length(rg.name) <= 90 &&
      can(regex("^[A-Za-z0-9_().-]+$", rg.name)) &&
      !endswith(rg.name, ".")
    ])
    error_message = "Resource group names must be 1-90 characters, use only letters, numbers, underscore, parentheses, hyphen or period, and must not end with a period."
  }

  validation {
    condition = length(distinct([
      for rg in values(var.resource_groups) : lower(rg.name)
    ])) == length(var.resource_groups)
    error_message = "Resource group names must be unique within this configuration (case-insensitive)."
  }

  validation {
    condition = alltrue([
      for rg in values(var.resource_groups) :
      lower(trimspace(rg.location)) == "centralus"
    ])
    error_message = "Every resource group must use the Azure region identifier "centralus"."
  }

  validation {
    condition = alltrue([
      for rg in values(var.resource_groups) :
      rg.virtual_network == null ? true :
      length(rg.virtual_network.address_space) > 0 &&
      alltrue([
        for prefix in rg.virtual_network.address_space : can(cidrhost(prefix, 0))
      ]) &&
      alltrue([
        for subnet in values(rg.virtual_network.subnets) :
        length(subnet.address_prefixes) > 0 &&
        alltrue([for prefix in subnet.address_prefixes : can(cidrhost(prefix, 0))])
      ])
    ])
    error_message = "Each configured virtual network must have at least one address space, and each subnet must have at least one address prefix."
  }

  validation {
    condition = alltrue([
      for rg in values(var.resource_groups) :
      rg.virtual_network == null ? true :
      length(distinct([
        for subnet in values(rg.virtual_network.subnets) : lower(subnet.name)
      ])) == length(rg.virtual_network.subnets)
    ])
    error_message = "Subnet names must be unique within each virtual network (case-insensitive)."
  }
  validation {
    condition = alltrue([
      for rg in values(var.resource_groups) :
      rg.virtual_network == null ? true :
      length(rg.virtual_network.name) >= 2 &&
      length(rg.virtual_network.name) <= 64 &&
      can(regex("^[A-Za-z0-9_.-]+$", rg.virtual_network.name))
    ])
    error_message = "Virtual network names must be 2-64 characters and contain only letters, numbers, periods, underscores, or hyphens."
  }

  validation {
    condition = alltrue([
      for rg in values(var.resource_groups) :
      rg.virtual_network == null ? true :
      alltrue([
        for subnet in values(rg.virtual_network.subnets) :
        length(subnet.name) >= 1 &&
        length(subnet.name) <= 80 &&
        can(regex("^[A-Za-z0-9_.-]+$", subnet.name))
      ])
    ])
    error_message = "Subnet names must be 1-80 characters and contain only letters, numbers, periods, underscores, or hyphens."
  }

}
