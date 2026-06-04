# C-017 (Amendment 2026-05-30) — the Foundry project inherits its
# public-network-access toggle (and location/tags) from the parent
# Cognitive Services account; no module-local defaults remain.
locals {
  # FR-043 / C-058 (Amendment 2026-06-04) — fixed BYO connection names the
  # project-level capability host references. These MUST match the account
  # module's local.agent_conn_* constants in modules/aifoundry/locals.tf
  # EXACTLY (the connections live on the parent account, isSharedToAll=true,
  # and are referenced here by name). A single account per stack (root
  # precondition aifoundry_project_requires_account) guarantees no collision;
  # the module test asserts these exact literals (VC-22).
  agent_conn_storage = "agentstorage"
  agent_conn_cosmos  = "agentcosmos"
  agent_conn_search  = "agentsearch"
}

