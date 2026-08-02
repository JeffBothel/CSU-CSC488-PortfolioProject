locals {
  root_resource_group_name = azurerm_resource_group.root.name
  root_location            = azurerm_resource_group.root.location

  foundry_account_name = "foundry-csc488"
  speech_account_name  = "speech-csc488"
  agent_account_name   = "agent-csc488"
  search_service_name  = "aisearchcsc488"

  foundry_service_models = {
    foundry_gpt-chat_small = {
      deployment_name = "foundry-gpt-chat-small"
      model_name      = "gpt-5.4-mini"
      sku_name        = "GlobalStandard"
      model_version   = "2026-03-17"
      capacity        = 10
    }
    foundry_embed = {
      deployment_name = "foundry-embed-main"
      model_name      = "text-embedding-3-large"
      sku_name        = "GlobalStandard"
      model_version   = "1"
      capacity        = 5
    }
  }

  agent_service_models = {
    agent_gpt-chat_small = {
      deployment_name = "agent-gpt-chat-small"
      model_name      = "gpt-5.4-mini"
      sku_name        = "GlobalStandard"
      model_version   = "2026-03-17"
      capacity        = 10
    }
    agent_gpt-chat_large = {
      deployment_name = "agent-gpt-chat-large"
      model_name      = "gpt-5.4"
      sku_name        = "GlobalStandard"
      model_version   = "2026-03-05"
      capacity        = 5
    }
    agent_embed = {
      deployment_name = "agent-embed-main"
      model_name      = "text-embedding-3-large"
      sku_name        = "GlobalStandard"
      model_version   = "1"
      capacity        = 5
    }
  }
}

# Microsoft Foundry-aligned AI account (multi-service) with open inbound and VNet-linked egress intent
resource "azurerm_cognitive_account" "foundry" {
  name                  = local.foundry_account_name
  provider              = azurerm.environment
  location              = azurerm_resource_group.root.location
  resource_group_name   = azurerm_resource_group.root.name
  custom_subdomain_name = local.foundry_account_name
  kind                  = "AIServices"
  sku_name              = "S0"

  public_network_access_enabled      = true
  outbound_network_access_restricted = false

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.service_endpoints,
    azurerm_subnet.private_endpoints,
    azurerm_log_analytics_workspace.main,
    azurerm_application_insights.main,
    azurerm_cosmosdb_account.foundry,
    azurerm_storage_account.foundry,
    azurerm_key_vault.main
  ]

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"

    virtual_network_rules {
      subnet_id = azurerm_subnet.service_endpoints.id
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
  sku_name              = "S0"

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
  sku_name              = "S0"

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"

    virtual_network_rules {
      subnet_id = azurerm_subnet.service_endpoints.id
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

# Permit Foundry and Agent OpenAI managed identities to integrate with AI Search
# for retrieval-augmented prompts and index operations.
resource "azurerm_role_assignment" "foundry_search_service_contributor" {
  provider             = azurerm.environment
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_cognitive_account.foundry.identity[0].principal_id

  depends_on = [
    azurerm_search_service.ai_search,
    azurerm_cognitive_account.foundry
  ]
}

resource "azurerm_role_assignment" "foundry_search_index_data_reader" {
  provider             = azurerm.environment
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azurerm_cognitive_account.foundry.identity[0].principal_id

  depends_on = [
    azurerm_search_service.ai_search,
    azurerm_cognitive_account.foundry
  ]
}

resource "azurerm_role_assignment" "agent_search_service_contributor" {
  provider             = azurerm.environment
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_cognitive_account.agent_services.identity[0].principal_id

  depends_on = [
    azurerm_search_service.ai_search,
    azurerm_cognitive_account.agent_services
  ]
}

resource "azurerm_role_assignment" "agent_search_index_data_reader" {
  provider             = azurerm.environment
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azurerm_cognitive_account.agent_services.identity[0].principal_id

  depends_on = [
    azurerm_search_service.ai_search,
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

resource "azurerm_cognitive_deployment" "foundry_models" {
  for_each             = local.foundry_service_models
  provider             = azurerm.environment
  name                 = each.value.deployment_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = each.value.sku_name
    capacity = each.value.capacity
  }

  depends_on = [
    azurerm_cognitive_account.foundry
  ]
}

resource "azurerm_cognitive_deployment" "agent_models" {
  for_each             = local.agent_service_models
  provider             = azurerm.environment
  name                 = each.value.deployment_name
  cognitive_account_id = azurerm_cognitive_account.agent_services.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = each.value.sku_name
    capacity = each.value.capacity
  }

  depends_on = [
    azurerm_cognitive_account.agent_services
  ]
}

