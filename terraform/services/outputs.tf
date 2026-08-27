# Cross-stack consumer surface (contracts/cross-stack-outputs.md).
# Keys are engine-emitted canonical names; no per-resource _id/_name outputs;
# no subscription_id re-export.

output "resource_group_name" {
  description = "Canonical name of the services-stack svc RG."
  value       = azurerm_resource_group.svc.name
}

output "resource_group_id" {
  description = "Azure resource ID of the svc RG."
  value       = azurerm_resource_group.svc.id
}

output "resource_ids" {
  description = "Map keyed by engine-emitted canonical name -> Azure resource ID (excludes the svc RG)."
  value = merge(
    { for k, m in module.keyvault : k => m.resource_id },
    { for k, m in module.storage : k => m.resource_id },
    { for k, m in module.log_analytics : k => m.workspace_resource_id },
    { for k, m in module.app_insights : k => m.resource_id },
    { for k, m in module.container_registry : k => m.resource_id },
    { for k, m in module.container_app_environment : k => m.resource_id },
    { for k, m in module.cosmosdb : k => m.resource_id },
    { for k, m in module.user_assigned_identity : k => m.resource_id },
    { for k, m in module.search : k => m.resource_id },
    { for k, m in module.openai : k => m.resource_id },
    { for k, m in module.language : k => m.resource_id },
    { for k, m in module.doc_intel : k => m.resource_id },
    { for k, m in module.function_app : k => m.resource_id },
    { for k, m in module.logic_app : k => m.resource_id },
    { for k, m in module.aml_workspace : k => m.resource_id },
    { for k, m in module.apim : k => m.resource_id },
    { for k, m in module.sql_server : k => m.resource_id },
    { for k, m in module.data_factory : k => m.resource_id },
  )
}

output "resource_names" {
  description = "Passthrough convenience: { canonical_name = canonical_name } for every emitted service."
  value = {
    for k in concat(
      keys(module.keyvault), keys(module.storage), keys(module.log_analytics),
      keys(module.app_insights), keys(module.container_registry),
      keys(module.container_app_environment), keys(module.cosmosdb),
      keys(module.user_assigned_identity), keys(module.search), keys(module.openai),
      keys(module.language),
      keys(module.doc_intel), keys(module.function_app), keys(module.logic_app),
      keys(module.aml_workspace), keys(module.apim),
      keys(module.sql_server), keys(module.data_factory),
    ) : k => k
  }
}

output "naming" {
  description = "Passthrough of module.naming.names (engine output; CA-010)."
  value       = module.naming.names
}

output "engine_version" {
  description = "Semver of the embedded naming engine. Pin against this for change-detection."
  value       = module.naming.engine_version
}

# C-014 (Amendment 2026-05-31) — expose the resolved shared hub LA workspace
# id so cross-stack consumers (and terraform_test fixtures) can assert it
# matches the value passed into every diagnostic-capable wrapper. Sourced
# from data.terraform_remote_state.hub_log (terraform/services/data.log.tf).
output "shared_la_workspace_id" {
  description = "Azure resource ID of the SHARED hub Log Analytics workspace used by every diagnostic-capable wrapper in this stack (spec.md C-014)."
  value       = local.shared_la_workspace_id
}
