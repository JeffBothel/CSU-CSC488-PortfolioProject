resource "random_string" "storage_account_name" {
  length  = 24
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "azurerm_storage_account" "foundry" {
  provider                         = azurerm.environment
  name                             = random_string.storage_account_name.result
  resource_group_name              = azurerm_resource_group.main.name
  location                         = azurerm_resource_group.main.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  account_kind                     = "StorageV2"
  access_tier                      = "Hot"
  public_network_access_enabled    = false
  cross_tenant_replication_enabled = false
  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = false

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.private_endpoints,
  ]

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = {
    workload = "azure-foundry-agent-services"
  }
}

resource "azurerm_private_endpoint" "storage_blob" {
  provider            = azurerm.environment
  name                = "pep-${azurerm_storage_account.foundry.name}-blob"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.private_endpoints,
  ]

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.foundry.name}-blob"
    private_connection_resource_id = azurerm_storage_account.foundry.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_blob.id]
  }
}
