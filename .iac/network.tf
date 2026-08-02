locals {
  vnet_cidr = "10.40.0.0/16"
  vnet_subnets = {
    private_endpoints = "10.40.1.0/24"
    workload          = "10.40.2.0/24"
    azure_firewall    = "10.40.3.0/24"
    service_endpoints = "10.40.4.0/24"
  }
  private_dns_zones = {
    # Azure Key Vault
    key_vault = "privatelink.vaultcore.azure.net"

    # Azure OpenAI / Cognitive Services
    openai = "privatelink.openai.azure.com"
    cogsvc = "privatelink.cognitiveservices.azure.com"

    # Cosmos DB (SQL API)
    cosmos_sql = "privatelink.documents.azure.com"

    # Azure AI Search
    search = "privatelink.search.windows.net"

    # Azure Storage Account
    storage_blob  = "privatelink.blob.core.windows.net"
    storage_file  = "privatelink.file.core.windows.net"
    storage_queue = "privatelink.queue.core.windows.net"
    storage_table = "privatelink.table.core.windows.net"

    # Log Analytics / App Insights (Azure Monitor private link)
    monitor_global = "privatelink.monitor.azure.com"
    monitor_oms    = "privatelink.oms.opinsights.azure.com"
    monitor_ods    = "privatelink.ods.opinsights.azure.com"
    monitor_agent  = "privatelink.agentsvc.azure-automation.net"
    app_insights   = "privatelink.applicationinsights.azure.com"

    # Azure AI Foundry project related endpoint namespace
    ai_foundry = "privatelink.services.ai.azure.com"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-csc488"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  address_space       = [local.vnet_cidr]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  provider             = azurerm.environment
  resource_group_name  = azurerm_resource_group.root.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.vnet_subnets.private_endpoints]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  provider             = azurerm.environment
  resource_group_name  = azurerm_resource_group.root.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.vnet_subnets.workload]
}

resource "azurerm_subnet" "azure_firewall" {
  name                 = "AzureFirewallSubnet"
  provider             = azurerm.environment
  resource_group_name  = azurerm_resource_group.root.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.vnet_subnets.azure_firewall]
}

resource "azurerm_subnet" "service_endpoints" {
  name                 = "snet-service-endpoints"
  provider             = azurerm.environment
  resource_group_name  = azurerm_resource_group.root.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.vnet_subnets.service_endpoints]
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.Sql",
    "Microsoft.Web",
    "Microsoft.EventHub",
    "Microsoft.ServiceBus"
  ]
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-csc488-firewall"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "main" {
  name                = "azfw-csc488"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "fw-ipcfg"
    subnet_id            = azurerm_subnet.azure_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_route_table" "isolated_egress" {
  name                = "rt-csc488-isolated-egress"
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "default-via-firewall"
  provider               = azurerm.environment
  resource_group_name    = azurerm_resource_group.root.name
  route_table_name       = azurerm_route_table.isolated_egress.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "workload" {
  provider       = azurerm.environment
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.isolated_egress.id
}

# Private DNS zones for various Azure services that will be accessed via private endpoints in the VNet.
resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  provider            = azurerm.environment
  resource_group_name = azurerm_resource_group.root.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "zones" {
  for_each            = azurerm_private_dns_zone.zones
  name                = "lnk-csc488-${each.key}"
  provider            = azurerm.environment
  private_dns_zone_id = each.value.id
  virtual_network_id  = azurerm_virtual_network.main.id
}

