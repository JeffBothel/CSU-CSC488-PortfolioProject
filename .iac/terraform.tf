terraform {
  required_version = ">= 1.15.8"
  backend "azurerm" {
    use_azuread_auth = true
    use_oidc = true
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0.1"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.11.0"
    }
  }
}

provider "azurerm" {
  alias = "environment"
  subscription_id = var.SUBSCRIPTION_ID
  features {}
}

provider "azapi" {
  alias = "environment"
  subscription_id = var.SUBSCRIPTION_ID
}