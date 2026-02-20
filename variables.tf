variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group"
  default     = "rg-feciit-prod"
}

variable "location" {
  type        = string
  description = "Azure region for resources"
  default     = "eastus"
}

variable "environment" {
  type        = string
  description = "Environment name for tagging"
  default     = "production"
}

variable "project" {
  type        = string
  description = "Project name for tagging"
  default     = "feciit"
}

variable "swa_repo_url" {
  type        = string
  description = "GitHub repository URL for the Static Web App"
}

variable "swa_branch" {
  type        = string
  description = "Branch to deploy for the Static Web App"
  default     = "main"
}

variable "swa_app_location" {
  type        = string
  description = "Location of the application code in the repository"
  default     = "/"
}

variable "swa_output_location" {
  type        = string
  description = "Location of the built application assets"
  default     = ".output/public"
}

variable "swa_api_location" {
  type        = string
  description = "Location of the API code in the repository"
  default     = ""
}

variable "enable_custom_domain" {
  type        = bool
  description = "Whether to provision the custom domain for the SWA"
  default     = false
}

variable "swa_custom_domain" {
  type        = string
  description = "Custom domain associated with the SWA (required if enable_custom_domain is true)"
  default     = "www.example.com"
}

variable "db_admin_user" {
  type        = string
  description = "Administrator login for PostgreSQL Flexible Server"
  default     = "feciitadmin"
}

variable "db_admin_password" {
  type        = string
  description = "Administrator password for PostgreSQL Flexible Server"
  sensitive   = true
}

variable "alert_email_addresses" {
  type        = list(string)
  description = "List of email addresses for Azure Monitor alerts"
}

variable "monitor_users_password" {
  type        = string
  description = "Password for the read-only monitoring users"
  sensitive   = true
}
