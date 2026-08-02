resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-csc488"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "main" {
  name                = "appi-csc488"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  depends_on          = [azurerm_log_analytics_workspace.main]
}

resource "azurerm_monitor_private_link_scope" "main" {
  name                = "ampls-csc488"
  provider            = azurerm.environment
  resource_group_name = azurerm_resource_group.root.name

  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"
}

resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "ampls-law-csc488"
  provider            = azurerm.environment
  resource_group_name = azurerm_resource_group.root.name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_monitor_private_link_scoped_service" "appi" {
  name                = "ampls-appi-csc488"
  provider            = azurerm.environment
  resource_group_name = azurerm_resource_group.root.name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_application_insights.main.id
}

resource "azurerm_private_endpoint" "ampls" {
  name                = "pep-ampls-csc488"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-ampls-csc488"
    private_connection_resource_id = azurerm_monitor_private_link_scope.main.id
    is_manual_connection           = false
    subresource_names              = ["azuremonitor"]
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.zones["monitor_global"].id,
      azurerm_private_dns_zone.zones["monitor_oms"].id,
      azurerm_private_dns_zone.zones["monitor_ods"].id,
      azurerm_private_dns_zone.zones["monitor_agent"].id,
      azurerm_private_dns_zone.zones["app_insights"].id,
    ]
  }

  depends_on = [
    azurerm_subnet.private_endpoints,
    azurerm_monitor_private_link_scoped_service.law,
    azurerm_monitor_private_link_scoped_service.appi,
  ]
}
