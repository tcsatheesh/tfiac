locals {
  defaults = {
    plan_sku_name = "Y1"
    os_type       = "Linux"
  }

  config = merge(local.defaults, var.overrides)

  plan_name = format("plan-%s", var.canonical_name)

  # Storage acct for the function app: operator MUST supply the
  # connection string + name via overrides for production. v1 uses
  # placeholders so plan succeeds with mock_provider.
  storage_account_name       = lookup(var.overrides, "storage_account_name", "stshdshdsp01npduks001")
  storage_account_access_key = lookup(var.overrides, "storage_account_access_key", "PLACEHOLDER")
}
