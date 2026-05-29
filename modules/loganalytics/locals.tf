# T007 - wrapper-module derivations.
#
# Naming-engine plumbing for the centralised log analytics workspace.
# Wrapper-level constants `usecase = "shd"` and `service_purpose = "shd"` are
# baked here so the public surface stays narrow (per Constitution II); operators
# never need to pass them. The root stack supplies `stack_purpose = "log"` in
# its locals.naming_input.
#
# Engine canonical names (per modules/naming/locals.tf):
#   workspace: log-{service_purpose}-{usecase}-{tenant}-{environment}-{region}-001
#              = log-shd-shd-hub-<env>-swc-001
#   RG:        rg-{stack_purpose}-{usecase}-{tenant}-{environment}-{region}-001
#              = rg-log-shd-hub-<env>-swc-001

locals {
  # ----- Wrapper-level constants stamped into the engine services list -----
  # `service_purpose` is hard-coded for the singleton "central" workspace; if a
  # future variant ever needs to coexist (e.g. a security-only workspace), add
  # a new entry to local.engine_services rather than parameterising this.
  workspace_service_purpose = "shd"
  rg_key                    = "main"

  # ----- Engine services list -----
  # Two entries: the workspace and the RG that contains it (FR-107).
  # `service_purpose = null` on the RG triggers the rg_hyphenated shape, which
  # already absorbs stack_purpose from var.input.stack_purpose (= "log").
  engine_services = [
    {
      service_type    = "log_analytics"
      key             = var.workspace_key
      service_purpose = local.workspace_service_purpose
      stack_purpose   = null
      fqdn            = null
      extra_tags      = {}
    },
    {
      service_type    = "resource_group"
      key             = local.rg_key
      service_purpose = null
      stack_purpose   = null
      fqdn            = null
      extra_tags      = {}
    },
  ]

  # ----- Locally-derived canonical names -----
  # Computed from the same var.input fields the engine hashes into the actual
  # resource names. Used in outputs.tf so the values are plan-time known (the
  # AVM modules' computed `name`/`resource_id` outputs are only known at apply).
  workspace_canonical_name = format(
    "log-%s-%s-%s-%s-%s-001",
    local.workspace_service_purpose,
    var.input.usecase,
    var.input.tenant,
    var.input.environment,
    var.input.region,
  )

  rg_canonical_name = format(
    "rg-%s-%s-%s-%s-%s-001",
    var.input.stack_purpose,
    var.input.usecase,
    var.input.tenant,
    var.input.environment,
    var.input.region,
  )

  # ----- Region long-form -----
  # The engine returns the Azure region long form on every emitted name's
  # `region` tag. Read it off the RG so we have a single lookup that doesn't
  # depend on the workspace having been created yet.
  region_full = module.naming.names[local.rg_canonical_name].tags.region
}
