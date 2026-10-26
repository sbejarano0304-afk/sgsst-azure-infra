resource "azurerm_container_registry" "main" {
  name                = "acr${var.project}${var.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"
  admin_enabled       = false # no shared username and password
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr_app_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_role_assignment" "acr_github_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github.object_id
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}