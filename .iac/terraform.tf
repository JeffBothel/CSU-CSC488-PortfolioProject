terraform {
  required_version = ">= 1.15.8"
  backend "azurerm" {
    use_azuread_auth = true
    use_oidc         = true
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
  alias           = "environment"
  subscription_id = var.AZURE_SUBSCRIPTION_ID
  features {}
}

provider "azapi" {
  alias           = "environment"
  subscription_id = var.AZURE_SUBSCRIPTION_ID
}

# Resource provider feature registration for allowing prviate endpoints is to be added at the subscription.
resource "azurerm_subscription_feature_registration" "allow_private_endpoints" {
  provider                = azurerm.environment
  name                    = "AllowPrivateEndpoints"
  resource_provider_name  = "Microsoft.Network"
}