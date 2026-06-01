# Plan — 103-sp01-dev-services

**Status**: Implemented (instance of engine [006-services](../006-services/spec.md))
**Branch**: `101-instance-numbering`
**Spec**: [spec.md](./spec.md)

## Nature of this feature

Instance feature. Pins one `variables/sp01/dev/services.tfvars.json` against
the already-shipped generic `terraform/services/` engine + the `modules/*`
service wrappers (feature 006). **No new selectable type, naming row, module,
or root-stack code** — a `10n` instance feature MUST NOT alter the `00n`
engine (those would be 006/001 amendments).

## Technology
- Consumes the 006-services engine unchanged (topology=spoke).
- State backend: hub-internal SA `sttfsshdhubnpdswc001` / container
  `tfstate`; key `sp01/dev/services.tfstate`.

## Artifacts owned by THIS feature
```
variables/sp01/dev/services.tfvars.json   # the only deployable artifact
.github/workflows/services.yml            # paths: watch entry (engine-owned)
```

## Architecture decisions (locked)

A1. **Selection**: `aifoundry`, `aifoundry_project`, `container_registry`,
    `container_app_environment`.
A2. **Private-by-default** (CLAUDE.md mandate): aifoundry PE + app insights,
    ACR PE, internal Container Apps env — all toggles `true`; PEs land on the
    `development` subnet role.
A3. **Cross-stack wiring**: `vnet_state_backend` → `sp01/npd/vnet.tfstate`
    (PE subnet + delegated container-apps subnet); `dns_state_backend` →
    `hub/prd/dns.tfstate`.
A4. **Documented deviation**: the ACA default-domain DNS zone is spoke-owned
    (006-services C-021) because its name is Azure-generated at apply time.
A5. **Environment**: `dev` (the services engine rejects `npd` per FR-025);
    consumes the `npd` spoke vnet subnets via remote state.

## Invariants (verified by the engine)
| # | Where | Description |
|---|---|---|
| 1 | engine root `region` | Must be `swc` |
| 2 | engine `check.subscription_pinned` | provider sub == var.subscription_id |
| 3 | engine `topology`/`environment` gates | topology=spoke; env ∈ {dev,pre,prd} |

## Test strategy
No new engine tests. Local `terraform fmt -recursive` + `terraform test`
(`-backend=false`) green across the touched service modules +
`terraform/services`. Live validation via `deploy.yaml` apply against
`sp01/dev/services.tfstate` AFTER the spoke vnet exists.

## Amendment plan — FR-103-05 (Foundry Hosted-Agent injection light-up)

**Scope.** Instance-only. Flip on Foundry Hosted-Agent network injection now
that the engine prerequisites (006 FR-032/033/034/035, 004/102 agents subnet)
are all merged. ONLY `specs/103-*` + `variables/sp01/dev/services.tfvars.json`
change — no engine code (FR-103-01).

**tfvars edits (the only deployable artifact).**
- `services[]` += `storage`, `cosmosdb`, `search` (the BYO Agent trio).
- `enable_aifoundry_network_injection`: `true` (FR-033).
- `enable_storage_private_endpoint`: `true` (FR-034).
- `enable_search_private_endpoint`: `true` (FR-035).
- `enable_container_registry_private_endpoint`: **`false`** (VC-7 ACR public
  exception — the ONE documented private-by-default deviation).
- `agent_subnet_role`: `agents` (default; pinned explicitly for clarity).
- `enable_aifoundry_private_endpoint`: `true` (unchanged — injection prereq).

**Engine invariants relied on (already merged, NOT changed here).**
- `check.aifoundry_network_injection_prereqs` — injection ⇒ private account +
  exactly one each of aifoundry/storage/cosmosdb/search.
- `check.storage_pe_requires_storage` / `check.search_pe_requires_search`.
- `enable_aifoundry_network_injection` requires `vnet_state_backend` (agents
  subnet) and `enable_aifoundry_private_endpoint = true`.

**Verification (local, no live state).** `terraform fmt -recursive` +
`terraform test` (engine suites unchanged & green); `terraform validate` of
the stack; manual JSON sanity of the tfvars. **No local apply** (FR-103-04).

**Rollout (operator-run, VC-8/VC-9).** Destructive Foundry recreate: operator
purges the existing Foundry account + `Agents` capability host, THEN dispatches
`deploy.yaml` (`service=services tenant=sp01 environment=dev action=apply
apply=true`). The agent does NOT execute this. See the spec's operator runbook.
