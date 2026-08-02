variable "name_prefix" {
  description = "Prefix used for logging resource names."
  type        = string
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-csc488"
  provider            = azurerm.environments
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "main" {
  name                = "appi-csc488"
  provider            = azurerm.environments
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  depends_on          = [azurerm_log_analytics_workspace.main]
}

resource "azurerm_private_endpoint" "law" {
  name                = "pep-law-csc488"
  provider            = azurerm.environments
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint.id
  depends_on          = [azurerm_log_analytics_workspace.main, azurerm_subnet.private_endpoint]

  private_service_connection {
    name                           = "psc-law-csc488"
    private_connection_resource_id = azurerm_log_analytics_workspace.main.id
    is_manual_connection           = false
    subresource_names              = ["workspaces"]
  }
}

resource "azurerm_private_endpoint" "appi" {
  name                = "pep-appi-csc488"
  provider            = azurerm.environments
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint.id
  depends_on          = [azurerm_application_insights.main, azurerm_subnet.private_endpoint]

  private_service_connection {
    name                           = "psc-appi-csc488"
    private_connection_resource_id = azurerm_application_insights.main.id
    is_manual_connection           = false
    subresource_names              = ["components"]
  }
}
