# Storage locations for OpenAI fine-tuning datasets.
resource "azurerm_storage_container" "openai_finetune_training" {
  provider              = azurerm.environment
  name                  = "openai-finetune-training"
  storage_account_id    = azurerm_storage_account.foundry.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "openai_finetune_validation" {
  provider              = azurerm.environment
  name                  = "openai-finetune-validation"
  storage_account_id    = azurerm_storage_account.foundry.id
  container_access_type = "private"
}

# Allow the Azure OpenAI account managed identity to read fine-tuning data from storage.
resource "azurerm_role_assignment" "agent_services_storage_blob_data_reader" {
  provider             = azurerm.environment
  scope                = azurerm_storage_account.foundry.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_cognitive_account.agent_services.identity[0].principal_id

  depends_on = [
    azurerm_storage_account.foundry,
    azurerm_cognitive_account.agent_services
  ]
}

# Optional deployment for a previously trained fine-tuned model.
# The fine-tuning job itself is created outside Terraform (API/SDK/CLI), then deployed here.
resource "azurerm_cognitive_deployment" "agent_services_finetuned" {
  count                = 1
  provider             = azurerm.environment
  name                 = "ft-gpt-mini0"
  cognitive_account_id = azurerm_cognitive_account.agent_services.id

  model {
    format  = "OpenAI"
    name    = "gpt-5.4-mini"
    version = "2024-07-18"
  }

  sku {
    name     = "Standard"
    capacity = 1
  }

  depends_on = [
    azurerm_cognitive_account.agent_services,
    azurerm_role_assignment.agent_services_storage_blob_data_reader
  ]
}