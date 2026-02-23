output "swa_default_hostname" {
  value       = azurerm_static_web_app.swa.default_host_name
  description = "The default hostname of the Static Web App"
}

output "swa_api_key" {
  value       = azurerm_static_web_app.swa.api_key
  description = "The deployment token/API key of the Static Web App"
  sensitive   = true
}

output "storage_connection_string" {
  value       = azurerm_storage_account.storage.primary_connection_string
  description = "The primary connection string for the Storage Account"
  sensitive   = true
}

output "postgres_fqdn" {
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
  description = "The fully qualified domain name of the PostgreSQL flexible server"
  sensitive   = true
}

output "swa_api_deployment_token" {
  value       = azurerm_static_web_app.swa.api_key
  description = "The deployment token needed for GitHub Actions to deploy your Nuxt app."
  sensitive   = true
}

output "swa_naked_domain_token" {
  description = "Validation token needed for the naked domain TXT record to prove ownership"
  value       = length(azurerm_static_web_app_custom_domain.swa_naked_domain) > 0 ? azurerm_static_web_app_custom_domain.swa_naked_domain[0].validation_token : null
  sensitive   = true
}
