variable "name" {
  description = "Base name for network resources."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnet_cidr" {
  description = "Virtual network CIDR range."
  type        = list(string)
}

variable "subnet_cidr" {
  description = "Workload subnet CIDR range."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
