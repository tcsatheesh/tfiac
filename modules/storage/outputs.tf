output "storage_account_id" {
  value = module.this.resource_id
}

output "storage_account_name" {
  value = module.this.name
}

output "storage_account_key" {
  value = module.this.resource.primary_access_key
}
