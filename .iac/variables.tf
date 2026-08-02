variable "AZURE_SUBSCRIPTION_ID" {
  description = "The subscription ID for the Azure account."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.SUBSCRIPTION_ID))
    error_message = "SUBSCRIPTION_ID must be a valid Azure subscription GUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."
  }
}