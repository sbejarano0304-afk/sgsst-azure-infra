resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.project}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = azurerm_subnet.aca.id
  tags                       = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  # Azure names a managed resource group for the environment itself;
  # without this, every plan would try to change it back.
  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }
}

locals {
  # Key Vault secret name => environment variable the api expects
  api_secrets = {
    "supabase-url"         = "SUPABASE_URL"
    "supabase-anon-key"    = "SUPABASE_ANON_KEY"
    "supabase-service-key" = "SUPABASE_SERVICE_KEY"
    "database-url"         = "DATABASE_URL"
  }
  registry = azurerm_container_registry.main.login_server
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${var.project}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = local.registry
    identity = azurerm_user_assigned_identity.app.id
  }

  # A reference, not a value: Container Apps fetches it from Key Vault
  # with the managed identity. No secret value in code or state.
  dynamic "secret" {
    for_each = local.api_secrets
    content {
      name                = secret.key
      identity            = azurerm_user_assigned_identity.app.id
      key_vault_secret_id = "${azurerm_key_vault.main.vault_uri}secrets/${secret.key}"
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "api"
      image  = "${local.registry}/sgsst-api:bootstrap"
      cpu    = 0.5
      memory = "1Gi"

      dynamic "env" {
        for_each = local.api_secrets
        content {
          name        = env.value
          secret_name = env.key
        }
      }
    }
  }

  # CI deploys new images (Step 5); don't let Terraform roll them back
  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }

  depends_on = [
    azurerm_role_assignment.acr_app_pull,
    azurerm_role_assignment.kv_app,
    azurerm_private_endpoint.kv,
  ]
}

resource "azurerm_container_app" "web" {
  name                         = "ca-${var.project}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = local.registry
    identity = azurerm_user_assigned_identity.app.id
  }

  ingress {
    external_enabled = false
    target_port      = 3000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "web"
      image  = "${local.registry}/sgsst-web:bootstrap"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }

  depends_on = [azurerm_role_assignment.acr_app_pull]
}

# The GitHub deploy identity: update these two apps, nothing else.
resource "azurerm_role_assignment" "github_rg_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.github.object_id
}

resource "azurerm_role_assignment" "github_apps" {
  for_each = {
    api = azurerm_container_app.api.id
    web = azurerm_container_app.web.id
  }
  scope                = each.value
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github.object_id
}

# Updating an app that uses a user-assigned identity also requires the
# right to "assign" that identity. Without this, deploys fail with a
# linked authorization error.
resource "azurerm_role_assignment" "github_identity_operator" {
  scope                = azurerm_user_assigned_identity.app.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azuread_service_principal.github.object_id
}