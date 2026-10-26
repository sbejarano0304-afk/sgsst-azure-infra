terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-sgsst-tfstate"
    storage_account_name = "sttfstatesb3306"
    container_name       = "tfstate"
    key                  = "sgsst.tfstate"
    use_azuread_auth     = true
  }
}
