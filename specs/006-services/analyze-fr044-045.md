# Analyze — FR-044 userOwnedStorage + FR-045 Key Vault connection

Cross-artifact consistency pass over `spec.md` (FR-044 / FR-045 + C-060 / C-061 /
VC-23…VC-27 + the private-by-default deviation), `plan.md` (the FR-044/045
amendment-plan section A-044-01…A-045-08), and `tasks.md` (Phase FR-044/045).
Non-destructive.

| ID | Severity | Dimension | Question | Finding |
|----|----------|-----------|----------|---------|
| A-FR044-1 | BLOCKER | Traceability | Is every FR-044/045 clarification + VC traced to a task and to code? | RESOLVED. C-060 (two storages by service_purpose, single-storage fallback, relaxed injection prereq) → T-FR044-006/-008; C-061 (fixed short names, private KV) → T-FR044-003/-008. VC-23 → T-FR044-009; VC-24 → T-FR044-009; VC-25 → T-FR044-010; VC-26 → T-FR044-011/-012; VC-27 → T-FR044-012. |
| A-FR044-2 | BLOCKER | Plan-time determinism | Can the new connection `count`/`for_each` depend on a value unknown at plan? | RESOLVED. The first implementation gated `count` on `var.*_account_id != null`, but the ids are computed (`module.storage`/`module.keyvault` outputs) ⇒ unknown at plan ⇒ "Invalid count argument". Fixed by introducing KNOWN-at-plan bool gates (`account_storage_connection_enabled`, `keyvault_connection_enabled`) — mirrors the `network_injection_enabled` precedent — and driving `count` off the bools. The ids carry only the value. (A-044-01) |
| A-FR044-3 | BLOCKER | Day-one parity | Do both toggles off reproduce the pre-amendment account body byte-for-byte? | RESOLVED. Both module bools default `false` ⇒ `userOwnedStorage` body leg omitted, `accountstorage` + `keyvault` connections zero-count. VC-25 test (T-FR044-010) asserts exactly this. Services toggles also default `false`. |
| A-FR044-4 | MAJOR | Two-storage disambiguation | With a 2nd storage, does the existing `one([all storage])` agent resolver break? | RESOLVED. It would (returns >1 ⇒ error). Replaced by purpose-filtered resolvers `agent_byo_storage_id` / `account_owned_storage_id` (filter on `module.naming.names[k].service_purpose`); single-storage + null-purpose collapses to `one([all])` (back-compat). The naming engine already yields distinct canonical names per storage entry, so NO `001-naming` change (C-060). |
| A-FR044-5 | MAJOR | Misconfig hard-stop vs module precondition | Does a misconfig (toggle on, dep missing) surface as the expected guard without an extra unhandled error? | RESOLVED. The module-passed enable bools are gated `toggle && <dep-selected>` so the module is never handed `enabled = true` + `id = null` (which would fire the module precondition as an unexpected error in the reject tests). The root `check.aifoundry_user_owned_storage_prereqs` / `aifoundry_keyvault_connection_prereqs` are the single loud guards; the module preconditions remain as belt-and-suspenders for direct module misuse. VC-26/VC-27 reject tests pass. |
| A-FR044-6 | MAJOR | azapi schema | Is `authType = AccountManagedIdentity` accepted by the provider? | RESOLVED. azapi's embedded connection schema lacks `AccountManagedIdentity` (only generic `ManagedIdentity`), so the KV connection sets `schema_validation_enabled = false` to send the template-exact, RP-valid value. Scoped to that one resource; all other resources keep schema validation on. |
| A-FR044-7 | MAJOR | Private-by-default deviation | Is deploying the KV PRIVATE (vs the PUBLIC portal vault) correct and documented? | RESOLVED. CLAUDE.md mandates private-by-default; the spec's "DEVIATION" block documents that the `keyvault` selection is deployed PRIVATE (PE + PNA disabled) — strictly MORE private than the template. The `AccountManagedIdentity` connection works identically against a private vault over the spoke VNet. |
| A-FR044-8 | MAJOR | Engine/instance split | Does the amendment touch any `10n` instance or other engine? | RESOLVED. Engine-only: `modules/aifoundry/*` + `terraform/services/{variables,locals,main,check}.tf` + their tests. No `variables/**`, no `specs/10n-*`. The sp01/dev selection (2nd storage + KV, drop ACR, flip toggles) is the separate `103` instance feature; the role assignments are the separate `007-rbac` engine. Both explicitly out-of-scope in the spec. |
| A-FR044-9 | MAJOR | Naming/DNS catalogue | New 001 naming row or 002 DNS zone needed? | RESOLVED. No. The 2nd storage is just an extra `storage` selection (existing row); the KV is the existing `keyvault` row + `privatelink.vaultcore.azure.net` (already in 002). The connections use fixed RP-side names, not engine-emitted canonical names. |
| A-FR044-10 | MAJOR | Connection target shapes | Are the connection `target` values RP-valid? | RESOLVED. The `accountstorage` (AzureStorageAccount) target is the Blob endpoint URI (reuses the C-031-06 derivation; the RP rejects a resource ID for storage connections); the `keyvault` (AzureKeyVault) target is the vault resource ID (RP-valid, mirrors the portal). VC-23/VC-24 assert these. |
| A-FR044-11 | MINOR | Tests | Positive + negative + default-off coverage? | RESOLVED. Positive: module both-on (VC-23/24), services happy two-storage+KV (VC-26). Negative: services reject ≠2-storage (VC-26) + reject KV-without-vault (VC-27). Default-off: module both-off (VC-25). 19 module + 28 services pass. |
| A-FR044-12 | MINOR | CI | Does CI watch the changed paths? | RESOLVED. The `services.yml` matrix already covers `modules/aifoundry` + `terraform/services`; no CI change needed. |

## Verdict

No outstanding BLOCKER/MAJOR findings. FR-044/FR-045 are additive and
default-off: the userOwnedStorage body leg + `accountstorage` connection and the
`keyvault` connection are `count`-gated on KNOWN-at-plan bool toggles (the
computed ids only carry values), so both toggles off reproduce the pre-amendment
account body byte-for-byte (VC-25), while on, they complete the portal Standard
Agent service graph (VC-23/VC-24). Two storages are disambiguated purely by
engine `service_purpose` (no `001-naming` change); the Key Vault is deployed
PRIVATE per the documented private-by-default deviation. Engine-only; the
`103` instance selection and `007-rbac` role assignments are out of scope.
`terraform fmt -recursive` clean; 19 module + 28 services tests green. Cleared.
