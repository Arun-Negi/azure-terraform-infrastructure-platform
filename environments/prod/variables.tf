variable "location" {
  description = "Azure region."
  type        = string
  default     = "centralindia"
}

variable "vnet_cidr" {
  description = "Virtual network address space."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_cidr" {
  description = "Workload subnet address space."
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default = {
    owner = "platform-team"
  }
}
