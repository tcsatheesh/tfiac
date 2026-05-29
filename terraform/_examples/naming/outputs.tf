output "names" {
  description = "Re-exposes the engine's name map for downstream inspection (terraform output -json names)."
  value       = module.names.names
}

output "engine_version" {
  description = "Re-exposes the engine version pin for consumer assertions."
  value       = module.names.engine_version
}
