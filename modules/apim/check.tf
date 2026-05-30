# Defence-in-depth precondition for spec.md C-013 (apim is hub-only).
# Mirrors the root-stack precondition at the wrapper boundary so any
# out-of-tree caller of modules/apim/ also gets the guard.
# A `terraform_data` precondition is used instead of `check {}` because
# `check` blocks emit warnings, not errors — we need hard-fail at plan.
resource "terraform_data" "topology_hub_only_guard" {
  lifecycle {
    precondition {
      condition = var.topology == "hub"
      error_message = format(
        "C-013 — apim is hub-only: this wrapper was invoked with topology=%q. APIM may only be provisioned from a hub stack (topology=\"hub\"). Move the apim selection into variables/hub/<env>/services.tfvars.json or drop it from the spoke selection.",
        var.topology,
      )
    }
  }
}
