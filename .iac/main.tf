# Configuration of the root Azure resource group for all the resources in this project.
resource "azurerm_resource_group" "root" {
  provider = azurerm.environment
  name     = "rg-csc488"
  location = "West US"
}