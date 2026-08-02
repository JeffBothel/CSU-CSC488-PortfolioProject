resource "azurerm_resource_group" "rg" {
  provider = azurerm.environment
  name     = "rg-csc488"
  location = "West US"
}