# The Azure Key Vault resource for secure storage of secrets, keys, and certificates
resource "azurerm_key_vault" "main" {
  name                          = "kv-csc488"
  provider                      = azurerm.environment
  location                      = azurerm_resource_group.root.location
  resource_group_name           = azurerm_resource_group.root.name
  tenant_id                     = var.AZURE_TENANT_ID
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false
  rbac_authorization_enabled    = true

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.private_endpoints
  ]

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

}

# Defined thie access policy separately after creation to allow for the key vault to be stood up and then associated to the Foundry account that will run it.
resource "azurerm_key_vault_access_policy" "foundry" {
  provider     = azurerm.environment
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.AZURE_TENANT_ID
  object_id    = azurerm_cognitive_account.foundry.identity[0].principal_id

  depends_on = [
    azurerm_key_vault.main,
    azurerm_cognitive_account.foundry
  ]

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

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${azurerm_key_vault.main.name}"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.private_endpoints
  ]

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.main.name}"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}