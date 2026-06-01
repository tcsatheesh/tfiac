locals {
  defaults = {
    sku             = "basic"
    replica_count   = 1
    partition_count = 1
  }

  config = merge(local.defaults, var.overrides)

  pe_name = "pep-${var.canonical_name}"
}
