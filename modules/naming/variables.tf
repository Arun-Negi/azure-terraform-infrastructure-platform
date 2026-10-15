variable "org" {
  description = "Organization code used in every generated resource name."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.org) >= 2 && length(var.org) <= 12 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.org))
    error_message = "naming.org must be 2-12 lowercase letters or digits, with single hyphens only between segments."
  }
}

variable "app" {
  description = "Application or platform code used in every generated resource name."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.app) >= 2 && length(var.app) <= 16 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.app))
    error_message = "naming.app must be 2-16 lowercase letters or digits, with single hyphens only between segments."
  }
}

variable "env" {
  description = "Environment code used in every generated resource name."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "test", "qa", "stage", "prod", "shared", "sandbox"], var.env)
    error_message = "naming.env must be one of: dev, test, qa, stage, prod, shared, sandbox."
  }
}

variable "resources" {
  description = "Map of resource name requests. Each resource declares its type code, instance identifier, Azure maximum name length, and allowed final-name pattern."
  type = map(object({
    type_code       = string
    instance        = string
    max_length      = number
    allowed_pattern = string
    compact_name    = optional(bool, false)
  }))
  nullable = false

  validation {
    condition = alltrue([
      for resource in values(var.resources) :
      length(resource.type_code) >= 2 &&
      length(resource.type_code) <= 8 &&
      can(regex("^[a-z0-9]+$", resource.type_code)) &&
      length(resource.instance) >= 1 &&
      length(resource.instance) <= 40 &&
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", resource.instance)) &&
      resource.max_length > 0
    ])
    error_message = "Each naming request must use a 2-8 character lowercase alphanumeric type code, a 1-40 character lowercase alphanumeric/hyphen instance, and a positive max_length."
  }
}
