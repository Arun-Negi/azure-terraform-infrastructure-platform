variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "naming" {
  description = "Organization, application, and environment components shared by every generated resource name."
  type = object({
    org = string
    app = string
    env = string
  })
  nullable = false
}

variable "resource_groups" {
  description = "Resource groups and optional networking. Resource names are generated from naming.org, naming.app, naming.env, type code, and each resource's instance."
  type = list(object({
    instance = string
    tags     = optional(map(string), {})
    virtual_network = optional(object({
      instance      = string
      address_space = list(string)
      subnets = optional(list(object({
        instance         = string
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
      length(rg.instance) >= 1 &&
      length(rg.instance) <= 40 &&
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", rg.instance))
    ])
    error_message = "Resource-group instance values must be 1-40 lowercase letters or digits, optionally separated by single hyphens."
  }

  validation {
    condition = length(distinct([
      for rg in var.resource_groups : lower(rg.instance)
    ])) == length(var.resource_groups)
    error_message = "Resource-group instance values must be unique, ignoring case."
  }

  validation {
    condition = alltrue([
      for rg in var.resource_groups : rg.virtual_network == null ? true : (
        length(rg.virtual_network.instance) >= 1 &&
        length(rg.virtual_network.instance) <= 40 &&
        can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", rg.virtual_network.instance)) &&
        length(rg.virtual_network.address_space) > 0 &&
        alltrue([for prefix in rg.virtual_network.address_space : can(cidrhost(prefix, 0))]) &&
        length(distinct([for subnet in rg.virtual_network.subnets : lower(subnet.instance)])) == length(rg.virtual_network.subnets) &&
        alltrue([
          for subnet in rg.virtual_network.subnets :
          length(subnet.instance) >= 1 &&
          length(subnet.instance) <= 40 &&
          can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", subnet.instance)) &&
          length(subnet.address_prefixes) > 0 &&
          alltrue([for prefix in subnet.address_prefixes : can(cidrhost(prefix, 0))])
        ])
      )
    ])
    error_message = "Check VNet/subnet instance values (1-40 lowercase letters/digits with single hyphens), unique subnet instances, and valid non-empty CIDR ranges."
  }
}
