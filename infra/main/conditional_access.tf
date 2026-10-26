locals {
  me = data.azuread_client_config.current.object_id
  # Windows Azure Service Management API: the portal, CLI, and Terraform
  azure_mgmt_app = "797f4846-ba00-4fd7-ba43-dac1f8f63013"
}

resource "azuread_conditional_access_policy" "admins_mfa" {
  display_name = "CA01-${var.project}-admins-require-mfa"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["all"]
    applications {
      included_applications = ["All"]
    }
    users {
      included_groups = [azuread_group.admins.object_id]
      excluded_users  = [local.me]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

resource "azuread_conditional_access_policy" "risky_signin_mfa" {
  display_name = "CA02-${var.project}-risky-signin-require-mfa"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types    = ["all"]
    sign_in_risk_levels = ["high", "medium"]
    applications {
      included_applications = ["All"]
    }
    users {
      included_users = ["All"]
      excluded_users = [local.me]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

resource "azuread_conditional_access_policy" "mgmt_compliant_device" {
  display_name = "CA03-${var.project}-azure-mgmt-compliant-device"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["all"]
    applications {
      included_applications = [local.azure_mgmt_app]
    }
    users {
      included_groups = [azuread_group.admins.object_id]
      excluded_users  = [local.me]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["compliantDevice"]
  }
}