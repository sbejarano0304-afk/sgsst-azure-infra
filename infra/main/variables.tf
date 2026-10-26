variable "project" {
  type    = string
  default = "sgsst"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "suffix" {
  type        = string
  description = "Your initials plus four digits, for globally unique names"
}

variable "alert_email" {
  type = string
}

variable "my_ip" {
  type        = string
  description = "Your public IP, so your Mac can write Key Vault secrets"
}

variable "github_repo" {
  type        = string
  description = "owner/name of sgsst-azure-infra"
}

locals {
  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}
