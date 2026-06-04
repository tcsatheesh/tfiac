# Analyze — Feature 104 (sp01/dev RBAC instance)

Cross-artifact consistency + quality gate for the sp01/dev instance of the
007-rbac engine. Scope: a single tfvars file; no engine code.

## Coverage

| ID | Requirement | Artifact(s) | Status |
|---|---|---|---|
| FR-104-01 | Engine unchanged | tasks T-104-04..06; no `terraform/rbac` or `modules/rbac` diff in this PR | RESOLVED |
| FR-104-02 | All config in tfvars | tfvars present; `subscription_id` placeholder; `services_state_backend` set | RESOLVED |
| FR-104-03 | Toggles/purposes match 103 | tfvars `agt`/`act` + both toggles `true` == 103 services tfvars | RESOLVED |
| FR-104-04 | Deploy via workflow only | plan/tasks Phase 4; no apply dispatched | RESOLVED |

## Consistency checks

- **Upstream key**: `services_state_backend.key = sp01/dev/services.tfstate`
  matches the 103 instance's backend state key (103 spec "Backend state key").
  ✓
- **Purpose parity**: `agent_storage_purpose=agt`, `account_storage_purpose=act`
  equal the 103 services tfvars (`storage` entries `agt`/`act`,
  `agent_storage_purpose=agt`, `account_storage_purpose=act`). ✓ — this is the
  load-bearing invariant: the RBAC engine resolves storages by the SAME
  purpose tokens the services engine used, so a mismatch would grant on the
  wrong (or no) storage. FR-104-03 captures it.
- **Toggle parity**: both `enable_aifoundry_user_owned_storage` and
  `enable_aifoundry_keyvault_connection` are `true` in both instances, so the
  engine's `check.tf` prereqs (two distinct storages present; KV present) are
  satisfiable against the 103 deployment. ✓
- **Backend account**: hub state account `rg-tfs-shd-hub-npd-swc-001` /
  `sttfsshdhubnpdswc001` / `tfstate` matches the account the 103 services
  tfvars uses for its own upstream reads. ✓
- **subscription_id**: placeholder + runtime injection mirrors the services
  instance convention (deploy.yaml `-var subscription_id=...`). ✓

## Validation evidence

- `terraform validate -backend=false` on `terraform/rbac`: **Success**.
- Engine `terraform test`: **5 stack passed** + **2 module passed**, 0 failed.
- tfvars JSON: parses; all keys are declared engine variables.

## Findings

No BLOCKER / MAJOR findings. The only cross-instance coupling
(purpose + toggle parity with 103) is documented as FR-104-03 and verified
above. RBAC live application is deferred to the operator (prepare-only).
