# FECIIT Azure Infrastructure

This repository contains the Terraform Infrastructure-as-Code (IaC) to automatically provision the cloud environment for the FECIIT national science fair.

## Features
* **Azure Static Web Apps**: Fully managed hosting for the Nuxt.js full-stack application.
* **Azure Database for PostgreSQL**: Flexible Server (Burstable Tier) for the application's primary datastore.
* **Azure Blob Storage**: Secure, private containers for Nuxt assets and daily database backups.
* **Azure Monitor**: Integrated Budget Alerts and operational logging.
* **Entra ID Access**: Secured, read-only monitoring access for specific users.

## Usage
1. Make sure you have the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and are logged in using `az login`.

2. Add a `terraform.tfvars` file (do not commit it!) based on the `variables.tf` requirements.

3. Run the deployment:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Collaborators & Attributions
This infrastructure was developed by the following contributors:
* **Blob Storage Architecture**: Sophia Esparza
* **SQL Azure Provisioning**: Yeshua Miranda
* **Azure Static Web Apps**: Isaac Vazquez