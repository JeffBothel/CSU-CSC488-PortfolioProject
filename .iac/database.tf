resource "azurerm_cosmosdb_account" "foundry" {
  provider            = azurerm.environment
  name                = "cosmos-foundry"
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.root.location
    failover_priority = 0
  }

  public_network_access_enabled = false
}

resource "azurerm_cosmosdb_sql_database" "foundry" {
  provider            = azurerm.environment
  name                = "foundry"
  resource_group_name = azurerm_resource_group.root.name
  account_name        = azurerm_cosmosdb_account.foundry.name
}

resource "azurerm_private_endpoint" "cosmosdb_foundry" {
  provider            = azurerm.environment
  name                = "pep-cosmos-foundry"
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.private_endpoints
  ]

  private_service_connection {
    name                           = "psc-cosmos-foundry"
    private_connection_resource_id = azurerm_cosmosdb_account.foundry.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }
}
