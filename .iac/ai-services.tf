locals {
  root_resource_group_name = azurerm_resource_group.root.name
  root_location            = azurerm_resource_group.root.location

  foundry_account_name = "foundry-csc488"
  speech_account_name  = "speech-csc488"
  agent_account_name   = "agent-csc488"
  search_service_name  = "aisearchcsc488"
}

# Microsoft Foundry-aligned AI account (multi-service) with open inbound and VNet-linked egress intent
resource "azurerm_cognitive_account" "foundry" {
  name                  = local.foundry_account_name
  provider              = azurerm.environment
  location              = azurerm_resource_group.root.location
  resource_group_name   = azurerm_resource_group.root.name
  custom_subdomain_name = local.foundry_account_name
  kind                  = "AIServices"
  sku_name              = "F0"

  public_network_access_enabled      = true
  outbound_network_access_restricted = false

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"

    virtual_network_rules {
      subnet_id = azurerm_subnet.workload.id
    }
  }

}

# Speech/Language services with storage attachment via diagnostics to shared storage
resource "azurerm_cognitive_account" "speech_language" {
  name                  = local.speech_account_name
  provider              = azurerm.environment
  location              = azurerm_resource_group.root.location
  resource_group_name   = azurerm_resource_group.root.name
  custom_subdomain_name = local.speech_account_name
  kind                  = "SpeechServices"
  sku_name              = "F0"

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"

    virtual_network_rules {
      subnet_id = azurerm_subnet.workload.id
    }
  }

  depends_on = [
    azurerm_cognitive_account.foundry
  ]
}

resource "azurerm_monitor_diagnostic_setting" "speech_to_storage" {
  name               = "diag-${local.speech_account_name}"
  provider           = azurerm.environment
  target_resource_id = azurerm_cognitive_account.speech_language.id
  storage_account_id = azurerm_storage_account.foundry.id

  enabled_log {
    category = "Audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [
    azurerm_cognitive_account.speech_language,
    azurerm_storage_account.foundry
  ]
}

# Agent services backend (Azure OpenAI account)
resource "azurerm_cognitive_account" "agent_services" {
  name                  = local.agent_account_name
  provider              = azurerm.environment
  location              = azurerm_resource_group.root.location
  resource_group_name   = azurerm_resource_group.root.name
  custom_subdomain_name = local.agent_account_name
  kind                  = "OpenAI"
  sku_name              = "F0"

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"

    virtual_network_rules {
      subnet_id = azurerm_subnet.workload.id
    }
  }

  depends_on = [
    azurerm_cognitive_account.foundry,
    azurerm_cognitive_account.speech_language
  ]
}

# AI Search service for Foundry integrations
resource "azurerm_search_service" "ai_search" {
  name                = local.search_service_name
  provider            = azurerm.environment
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  sku                 = "free"

  local_authentication_enabled  = true
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_cognitive_account.foundry,
    azurerm_cognitive_account.agent_services
  ]
}

resource "azurerm_monitor_diagnostic_setting" "ai_services_logs" {
  name                       = "diag-${local.foundry_account_name}"
  provider                   = azurerm.environment
  target_resource_id         = azurerm_cognitive_account.foundry.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [
    azurerm_cognitive_account.foundry,
    azurerm_log_analytics_workspace.main
  ]
}
