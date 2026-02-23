locals {
  tags = {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# 1. Azure Static Web App (SWA)
# -----------------------------------------------------------------------------
resource "azurerm_static_web_app" "swa" {
  name                = "stapp-${var.project}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_size            = "Standard"
  sku_tier            = "Standard"
  tags                = local.tags

  # Link the SWA directly to GitHub for automatic CI/CD
  # Note: The AzureRM Terraform provider manages the SWA structure, but linking the repo directly
  # here is no longer supported directly via these flags. See the output variable instead.

  # Inject Secrets & Environment Variables into the Nuxt Backend
  app_settings = {
    DATABASE_URL        = "postgresql://${var.db_admin_user}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.feciit_db.name}?sslmode=require"
    BETTER_AUTH_SECRET  = var.better_auth_secret
    BETTER_AUTH_URL     = var.better_auth_url
    SEED_ADMIN_EMAIL    = var.seed_admin_email
    SEED_ADMIN_NAME     = var.seed_admin_name
    SEED_ADMIN_PASSWORD = var.seed_admin_password
    NUXT_MAIL_HOST      = var.nuxt_mail_host
    NUXT_MAIL_PORT      = var.nuxt_mail_port
    NUXT_MAIL_USER      = var.nuxt_mail_user
    NUXT_MAIL_PASS      = var.nuxt_mail_pass
    NUXT_MAIL_FROM      = var.nuxt_mail_from
  }
}

resource "azurerm_static_web_app_custom_domain" "swa_domain" {
  count             = var.enable_custom_domain ? 1 : 0
  static_web_app_id = azurerm_static_web_app.swa.id
  domain_name       = var.swa_custom_domain
  validation_type   = "cname-delegation"
}

resource "azurerm_static_web_app_custom_domain" "swa_naked_domain" {
  count             = var.enable_custom_domain ? 1 : 0
  static_web_app_id = azurerm_static_web_app.swa.id
  domain_name       = var.swa_naked_domain
  validation_type   = "dns-txt-token"
}

# -----------------------------------------------------------------------------
# 2. Azure Blob Storage
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "storage" {
  name                     = "st${var.project}${var.environment}data"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "nuxt_assets" {
  name                  = "nuxt-assets"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "postgres_backups" {
  name                  = "postgres-backups"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "storage_lifecycle" {
  storage_account_id = azurerm_storage_account.storage.id

  rule {
    name    = "move_to_cool_and_delete"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than       = 90
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }
      version {
        delete_after_days_since_creation = 90
      }
    }
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "storage_diag" {
  name                       = "diag-storage"
  target_resource_id         = "${azurerm_storage_account.storage.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
  metric {
    category = "Transaction"
    enabled  = true
  }
}

# -----------------------------------------------------------------------------
# 3. Azure Database for PostgreSQL Flexible Server
# -----------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "psql-${var.project}-${var.environment}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "15"
  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  sku_name               = "B_Standard_B2s"
  tags                   = local.tags

  # 32768 MB (32 GB) is the absolute minimum storage allowed for Azure Postgres Flexible Server.
  storage_mb = 32768

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false # Geo-redundant backups are not supported on Burstable SKUs

  lifecycle {
    ignore_changes = [
      zone,
      high_availability.0.standby_availability_zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_personal_ip" {
  name             = "AllowPersonalIP"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = var.personal_ip
  end_ip_address   = var.personal_ip
}


resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_internal" {
  name             = "AllowAzureInternal"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "feciit_db" {
  name      = "feciit"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# -----------------------------------------------------------------------------
# 4. Azure Monitor — Budget Alert
# -----------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "alerts" {
  name                = "ag-${var.project}-alerts"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "feciitalerts"
  tags                = local.tags

  dynamic "email_receiver" {
    for_each = { for idx, email in var.alert_email_addresses : idx => email }
    content {
      name                    = "email-receiver-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = "budget-${var.project}-${var.environment}"
  resource_group_id = azurerm_resource_group.rg.id

  amount     = 200
  time_grain = "Monthly"

  time_period {
    start_date = "2026-03-01T00:00:00Z"
    end_date   = "2036-03-01T00:00:00Z" # Example long-term end date
  }

  notification {
    enabled        = true
    threshold      = 80.0
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.alert_email_addresses
  }

  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.alert_email_addresses
  }
}

# -----------------------------------------------------------------------------
# 5. Azure Monitor — Operational Alerts
# -----------------------------------------------------------------------------
# PostgreSQL Availability
resource "azurerm_monitor_metric_alert" "pg_availability" {
  name                = "alert-pg-down"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_postgresql_flexible_server.postgres.id]
  description         = "Triggers when PostgreSQL is_db_alive is 0"
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "is_db_alive"
    aggregation      = "Average"
    operator         = "LessThanOrEqual"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}

# PostgreSQL CPU
resource "azurerm_monitor_metric_alert" "pg_cpu" {
  name                = "alert-pg-cpu"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_postgresql_flexible_server.postgres.id]
  description         = "Triggers when PostgreSQL CPU > 80% for 5 mins"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}

# PostgreSQL Storage
resource "azurerm_monitor_metric_alert" "pg_storage" {
  name                = "alert-pg-storage"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_postgresql_flexible_server.postgres.id]
  description         = "Triggers when PostgreSQL Storage > 85%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}

# Blob Backup Monitoring
resource "azurerm_monitor_scheduled_query_rules_alert" "blob_backup_monitor" {
  name                = "alert-blob-backup-missing"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  description         = "Triggers if no files written to 'postgres-backups' over the last 24h"
  tags                = local.tags

  frequency   = 1440 # 24 hours in minutes
  time_window = 1440
  severity    = 2

  data_source_id = azurerm_log_analytics_workspace.law.id

  query = <<-EOT
    StorageBlobLogs
    | where Category == "StorageWrite"
    | where ObjectKey contains "postgres-backups"
  EOT

  trigger {
    operator  = "Equal"
    threshold = 0
  }

  action {
    action_group = [azurerm_monitor_action_group.alerts.id]
  }
}

# -----------------------------------------------------------------------------
# 6. Azure AD Users for Monitoring
# -----------------------------------------------------------------------------
data "azuread_domains" "default" {
  only_initial = true
}

resource "azuread_user" "monitor_user1" {
  user_principal_name = "monitor1@${data.azuread_domains.default.domains.0.domain_name}"
  display_name        = "Monitor User 1"
  password            = var.monitor_users_password
}

resource "azuread_user" "monitor_user2" {
  user_principal_name = "monitor2@${data.azuread_domains.default.domains.0.domain_name}"
  display_name        = "Monitor User 2"
  password            = var.monitor_users_password
}

resource "azurerm_role_assignment" "monitor_user1_role" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azuread_user.monitor_user1.object_id
}

resource "azurerm_role_assignment" "monitor_user2_role" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azuread_user.monitor_user2.object_id
}
