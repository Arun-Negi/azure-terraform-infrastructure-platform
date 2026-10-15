variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "org" {
  description = "Short organization code used in all generated resource names."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.org) >= 2 && length(var.org) <= 12 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.org))
    error_message = "org must be 2-12 lowercase letters or digits, optionally separated by single hyphens."
  }
}

variable "app" {
  description = "Application or platform code used in all generated resource names."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.app) >= 2 && length(var.app) <= 16 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.app))
    error_message = "app must be 2-16 lowercase letters or digits, optionally separated by single hyphens."
  }
}

variable "env" {
  description = "Environment code used in all generated resource names."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "test", "qa", "stage", "prod", "shared", "sandbox"], var.env)
    error_message = "env must be one of: dev, test, qa, stage, prod, shared, sandbox."
  }
}

variable "resource_groups" {
  description = "Resource groups and optional networking. Resource names are generated from org, app, env, resource type, and each resource's instance."
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
  validation {
    condition = alltrue([
      for rg in var.resource_groups :
      length("${var.org}-${var.app}-${var.env}-rg-${rg.instance}") <= 90 &&
      (rg.virtual_network == null ? true :
        length("${var.org}-${var.app}-${var.env}-vnet-${rg.virtual_network.instance}") <= 64 &&
        alltrue([
          for subnet in rg.virtual_network.subnets :
          length("${var.org}-${var.app}-${var.env}-snet-${subnet.instance}") <= 80
        ])
      )
    ])
    error_message = "A generated resource group, VNet, or subnet name exceeds its Azure length limit (90, 64, or 80 characters). Shorten org, app, env, or the resource instance."
  }
}


variable "storage_accounts" {
  description = "Optional storage accounts. Each account references a resource-group instance and uses platform-approved secure defaults."
  type = list(object({
    instance                      = string
    resource_group_instance       = string
    account_tier                  = optional(string, "Standard")
    replication_type              = optional(string, "LRS")
    min_tls_version               = optional(string, "TLS1_2")
    public_network_access_enabled = optional(bool, false)
    shared_access_key_enabled     = optional(bool, false)
    tags                          = optional(map(string), {})
  }))
  default  = []
  nullable = false

  validation {
    condition = (
      length(distinct([for account in var.storage_accounts : lower(account.instance)])) == length(var.storage_accounts) &&
      alltrue([for account in var.storage_accounts : length(account.instance) >= 1 && length(account.instance) <= 40 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", account.instance))])
    )
    error_message = "Storage account instances must be unique and use 1-40 lowercase letters/digits with optional single hyphens."
  }

  validation {
    condition = alltrue([for account in var.storage_accounts :
      contains(["Standard"], account.account_tier) &&
      contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], account.replication_type) &&
      account.min_tls_version == "TLS1_2"
    ])
    error_message = "Storage accounts support Standard tier, approved replication types LRS/GRS/RAGRS/ZRS/GZRS/RAGZRS, and TLS1_2 only."
  }

  validation {
    condition = alltrue([for account in var.storage_accounts :
      contains([for rg in var.resource_groups : rg.instance], account.resource_group_instance)
    ])
    error_message = "Each storage account resource_group_instance must match an instance declared in resource_groups."
  }
}
