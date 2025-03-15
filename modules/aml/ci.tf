resource "azurerm_machine_learning_compute_instance" "this" {
  for_each                      = tomap(var.services.aml.compute_instances)
  machine_learning_workspace_id = module.azureml.resource_id
  subnet_resource_id            = data.azurerm_subnet.this.id
  name                          = each.value.name
  virtual_machine_size          = each.value.vm_size
  description                   = each.value.description
  node_public_ip_enabled        = false

  identity {
    type         = "SystemAssigned,UserAssigned"
    identity_ids = [for id in each.value.user_assigned_identity : id]
  }
}
