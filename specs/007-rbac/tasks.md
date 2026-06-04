# Tasks — 007-rbac engine

Legend: `[ ]` todo · `[x]` done. Engine-only; instance (104) is separate.

## Phase 1 — module `modules/rbac/`

- [x] T-001 `modules/rbac/versions.tf` (terraform + azurerm + azapi).
- [x] T-002 `modules/rbac/variables.tf` (`role_assignments`,
  `cosmos_sql_role_assignments` typed maps + validation).
- [x] T-003 `modules/rbac/main.tf` (`azurerm_role_assignment` fan-out +
  `azapi_resource` cosmos sqlRoleAssignment fan-out).
- [x] T-004 `modules/rbac/outputs.tf`.
- [x] T-005 `modules/rbac/README.md`.
- [x] T-006 `modules/rbac/tests/happy.tftest.hcl` (N in → N assignments).
- [x] T-007 `modules/rbac/tests/default_empty.tftest.hcl` (empty → zero).

## Phase 2 — stack `terraform/rbac/`

- [x] T-008 `terraform/rbac/versions.tf` / `providers.tf` / `backend.tf`.
- [x] T-009 `terraform/rbac/variables.tf` (subscription_id,
  services_state_backend, two toggles, two purposes + validation).
- [x] T-010 `terraform/rbac/data.services.tf` (services remote state).
- [x] T-011 `terraform/rbac/data.principals.tf` (azapi account/project
  principalId data sources, presence-gated).
- [x] T-012 `terraform/rbac/locals.tf` (target-id resolution by
  service_type/purpose, presence bools, GUID map, role_assignments +
  cosmos_sql map construction).
- [x] T-013 `terraform/rbac/main.tf` (`module "rbac"`).
- [x] T-014 `terraform/rbac/check.tf` (uos + kvconn prereq checks).
- [x] T-015 `terraform/rbac/outputs.tf`.
- [x] T-016 `terraform/rbac/README.md`.

## Phase 3 — stack tests

- [x] T-017 `terraform/rbac/tests/_fixtures.tftest.hcl` (mock providers +
  services remote-state override helper).
- [x] T-018 `terraform/rbac/tests/happy_full_matrix.tftest.hcl` (VC-30/VC-32 —
  exact assignment counts + purpose-correct storage resolution).
- [x] T-019 `terraform/rbac/tests/default_off.tftest.hcl` (VC-31 — zero).
- [x] T-020 `terraform/rbac/tests/reject_user_owned_storage_without_two_storages.tftest.hcl`
  (VC-33).
- [x] T-021 `terraform/rbac/tests/reject_keyvault_connection_without_keyvault.tftest.hcl`
  (VC-34).

## Phase 4 — CI / rollout wiring

- [x] T-022 `.github/workflows/rbac.yml` (PR + push + matrix, mirror
  services.yml).
- [x] T-023 Add `rbac` to `deploy.yaml` `service` choice options.

## Phase 5 — verify

- [x] T-024 `terraform fmt -recursive` clean.
- [x] T-025 `terraform test` green for `modules/rbac` + `terraform/rbac`
  (VC-35).

## Phase 6 — analyze + rollout

- [x] T-026 `/speckit.analyze` remediation pass (analyze-rbac.md).
- [x] T-027 Branch `007-rbac` → PR → CI green → squash-merge (prepare-only;
  NO deploy).

## Phase 7 — FR-046 label correction (2026-06-04)

> The GUID `b86a8fe4-…` granted under the name "Crypto Service Encryption User"
> is actually **Key Vault Secrets Officer**. Pure relabel; same GUID, no
> permission change. This grant is what `006`'s secret-bearing connections need.

- [ ] T-028 `terraform/rbac/locals.tf`: rename `role_guids.kv_crypto_service_encryption_user`
  → `role_guids.kv_secrets_officer` (GUID unchanged) and the assignment key
  `account-kv-crypto-service-encryption-user` → `account-kv-secrets-officer`;
  update the `role_definition_id` reference. (FR-046/C-067)
- [ ] T-029 Update the FR-046 comment(s) to read "Key Vault Secrets Officer".
- [ ] T-030 Tests: assert the matrix still emits exactly one
  `account-kv-secrets-officer` grant with GUID `b86a8fe4-…`; no remaining
  `kv_crypto_service_encryption_user` reference (VC-36/VC-37).
- [ ] T-031 `terraform fmt -recursive` clean; `terraform test` green for
  `modules/rbac` + `terraform/rbac` (VC-35).
