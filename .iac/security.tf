resource "azurerm_key_vault" "this" {
  name                          = "kv-csc488"
  provider                      = azurerm.environment
  location                      = azurerm_resource_group.root.location
  resource_group_name           = azurerm_resource_group.root.name
  tenant_id                     = var.AZURE_TENANT_ID
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.private_endpoint
  ]

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  access_policy {
    tenant_id = var.AZURE_TENANT_ID
    object_id = azurerm_cognitive_account.foundry.principal_id

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Update",
      "Recover",
      "Purge"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Purge"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Update",
      "Recover",
      "Purge"
    ]
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${azurerm_key_vault.this.name}"
  provider            = azurerm.environment
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints

  depends_on = [
    azurerm_virtual_network.this,
    azurerm_subnet.private_endpoint
  ]

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.this.name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}