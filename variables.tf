variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
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
      length(trimspace(rg.location)) > 0
    ])
    error_message = "Every resource group must specify a non-empty Azure location."
  }

  validation {
    condition = alltrue([
      for rg in values(var.resource_groups) :
      rg.virtual_network == null ? true :
      length(rg.virtual_network.address_space) > 0 &&
      alltrue([
        for subnet in values(rg.virtual_network.subnets) :
        length(subnet.address_prefixes) > 0
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
}
