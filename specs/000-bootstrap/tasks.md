# Feature 000 — Bootstrap state SA — Tasks

> Phase letters: **B** = bootstrap stack code, **T** = tests, **O** = OIDC + GH env, **A** = live apply, **M** = migrate stacks, **W** = workflow, **D** = sp01 deploy.

## Phase B — Bootstrap stack code

- [ ] T001 Create `terraform/bootstrap/.gitignore` (ignores `.terraform/`, `terraform.tfstate*`, `*.tfvars` except `.example`).
- [ ] T002 Create `terraform/bootstrap/providers.tf` — azurerm (4.74.0, features {}, `subscription_id = var.subscription_id`, `use_oidc = true`), azuread (~> 3.0), random pinned to repo lock.
- [ ] T003 Create `terraform/bootstrap/backend.tf` — explicit `terraform { backend "local" {} }` with a header comment "RUN ONCE — local state by design; see FR-009."
- [ ] T004 Create `terraform/bootstrap/variables.tf` — `subscription_id` (string, validation = GUID regex), `operator_object_id` (string, default null, validation = GUID or null), `gh_oidc_object_id` (string, default null, validation = GUID or null).
- [ ] T005 Create `terraform/bootstrap/locals.tf` — `region_short="swc"`, `tenant="hub"`, `environment="npd"`, `role="hub"`, `usecase="tfs"`, `repo="tcsatheesh/tfiac"`, `build_vm = { rg = "rg-bld-shd-hub-npd-swc-001", name = "vm-bld-shd-hub-npd-swc-001" }`.
- [ ] T006 Create `terraform/bootstrap/data.tf` — `data.azurerm_client_config.current`, `data.terraform_remote_state.dns` (key `hub/prd/dns.tfstate`, **LEGACY backend** = `stcwetfstate01`), `data.terraform_remote_state.vnet` (key `hub/npd/vnet.tfstate`, **LEGACY backend** because the new SA does not yet exist at bootstrap time — see plan §8 step 2). Both data reads hard-coded to legacy backend; no toggle (the stack runs exactly once before any migration).
- [ ] T007 Create `terraform/bootstrap/data.tf` (continued) — `data.azurerm_linux_virtual_machine.build_vm` using locals.
- [ ] T008 Create `terraform/bootstrap/main.tf` — `module "naming"` (path = `../../modules/naming`), `azurerm_resource_group.this`, `azurerm_storage_account.this` (FR-002: all flags), `azurerm_storage_container.tfstate`, `azurerm_storage_account_blob_properties` for versioning + soft delete.
- [ ] T009 `terraform/bootstrap/main.tf` (continued) — `azurerm_private_endpoint.sa` in dev subnet (subnet id from vnet remote state), `azurerm_private_dns_a_record.sa` (zone id from dns remote state `zone_ids["blob"]`, A-record name = SA name, IP from PE NIC).
- [ ] T010 `terraform/bootstrap/main.tf` (continued) — three `azurerm_role_assignment` blocks: operator → Storage Blob Data Owner (conditional `count = var.operator_object_id != null ? 1 : 0`), build VM MI → Storage Blob Data Contributor, gh oidc → Storage Blob Data Contributor (conditional).
- [ ] T011 Create `terraform/bootstrap/outputs.tf` — `sa_id`, `sa_name`, `rg_name`, `container_name`, `pe_private_ip`, `a_record_fqdn`.
- [ ] T012 Create `terraform/bootstrap/README.md` — one-shot run instructions covering: open legacy SA firewall, `terraform init` (LOCAL), `terraform apply -var-file=terraform.tfvars`, re-lock legacy SA firewall.
- [ ] T013 `terraform fmt -recursive terraform/bootstrap/` — clean.
- [ ] T014 `cd terraform/bootstrap && terraform init -backend=false && terraform validate` — green.

## Phase T — Tests

- [ ] T015 [P] Create `terraform/bootstrap/tests/plan_creates_minimum_resources.tftest.hcl` — mocked providers, dns + vnet remote state overrides, asserts resource counts (1 RG, 1 SA, 1 container, 1 PE, 1 A-record, expected role assignments).
- [ ] T016 [P] Create `terraform/bootstrap/tests/aad_only_enforced.tftest.hcl` — asserts `shared_access_key_enabled == false`, `public_network_access_enabled == false`, `default_to_oauth_authentication == true` on the planned SA.
- [ ] T017 [P] Create `terraform/bootstrap/tests/pe_subnet_correct.tftest.hcl` — asserts the PE `subnet_id` matches the dev subnet returned by the mocked vnet remote state.
- [ ] T018 `cd terraform/bootstrap && terraform test` — all three pass on terraform 1.9.8 and 1.13.4.

## Phase W (paper) — Workflow + repo CI

- [ ] T019 Create `.github/workflows/bootstrap.yml` — fmt/init -backend=false/validate/test for `terraform/bootstrap` and (already-existing patterns) — modelled on `vnet.yml`.
- [ ] T020 Create `.github/workflows/deploy.yaml` replacing `deploy_all.yaml` (FR-012, plan §6). Delete the old `deploy_all.yaml`.
- [ ] T021 `gh workflow list` (post-PR merge) confirms `deploy` is registered.

## Phase O — Self-bootstrap OIDC + GH env (live, operator-laptop)

- [ ] T022 Create app registration `gh-oidc-tfiac-hub-npd` via `az ad app create`; capture `APP_ID`.
- [ ] T023 Create SP for the app via `az ad sp create --id $APP_ID`; capture `SP_OBJ_ID`.
- [ ] T024 Create federated credential scoped to `repo:tcsatheesh/tfiac:environment:hub-npd` via `az ad app federated-credential create`.
- [ ] T025 Grant the SP `Contributor` at subscription scope (`/subscriptions/883c9081-23ed-4674-95c5-45c74834e093`) via `az role assignment create`.
- [ ] T026 Create GH environment `hub-npd` via `gh api -X PUT repos/tcsatheesh/tfiac/environments/hub-npd`; restrict to `master` branch.
- [ ] T027 `gh secret set AZURE_CLIENT_ID/TENANT_ID/SUBSCRIPTION_ID --env hub-npd` with the values from T022..T025.
- [ ] T028 Append `SP_OBJ_ID` and operator object id (from `az ad signed-in-user show --query id -o tsv`) to `terraform/bootstrap/terraform.tfvars` (gitignored).

## Phase A — Bootstrap apply (live, operator-laptop)

- [ ] T029 Open legacy SA `stcwetfstate01` firewall to operator IP (mirror Phase 8 T111).
- [ ] T030 `cd terraform/bootstrap && rm -rf .terraform && terraform init` (LOCAL backend, no backend-config).
- [ ] T031 `terraform plan -var-file=terraform.tfvars -out=bootstrap.tfplan -no-color -input=false` — expected: `Plan: 7 to add (or +1 RG, +1 SA, +1 container, +1 PE, +1 A-record, +1..3 role assignments depending on vars), 0 to change, 0 to destroy`.
- [ ] T032 Inspect plan; verify no upstream resource is modified (FR-006).
- [ ] T033 `terraform apply bootstrap.tfplan` — confirm exit 0; capture `sa_id`, `pe_private_ip`, `a_record_fqdn` from outputs.
- [ ] T034 Re-lock legacy SA firewall.
- [ ] T035 Smoke test from operator wkst via Bastion → build VM: `az storage blob list --account-name sttfsshdhubnpdswc001 --container-name tfstate --auth-mode login` returns empty list (no 403).

## Phase M — Stack state migration (live, operator-laptop via Bastion → build VM)

- [ ] T036 Update `variables/backend.hcl` in-place to point at new SA (RG=`rg-tfs-shd-hub-npd-swc-001`, SA=`sttfsshdhubnpdswc001`, container=`tfstate`, `use_azuread_auth=true`, `subscription_id=883c9081-23ed-4674-95c5-45c74834e093`).
- [ ] T037 Update `variables/hub/npd/vnet.tfvars.json` `dns_state_backend.{resource_group_name,storage_account_name}` to new SA (the `key="hub/prd/dns.tfstate"` stays the same; dns state lives at the same key on the new SA after T038).
- [ ] T038 Migrate dns: open legacy SA firewall → `cd terraform/dns && rm -rf .terraform && terraform init -migrate-state -force-copy -backend-config=../../variables/backend.hcl -backend-config="key=hub/prd/dns.tfstate"` → confirm copy → `terraform plan -var-file=...` returns `No changes` → re-lock legacy.
- [ ] T039 Migrate vnet (hub): legacy SA open → init -migrate-state with key=`hub/npd/vnet.tfstate` → plan returns `No changes` → re-lock.
- [ ] T040 Migrate log: same with key=`hub/npd/log.tfstate` (or whatever existing key — confirm via legacy `terraform state list`).
- [ ] T041 Migrate buildsvr: same with key=`hub/npd/buildsvr.tfstate`.
- [ ] T042 Update `variables/sp01/npd/vnet.tfvars.json` `dns_state_backend.*` to new SA.

## Phase D — Sp01 npd vnet deploy via GH workflow (live)

- [ ] T043 PR all paper artefacts (bootstrap code, tests, new deploy workflow, backend.hcl, tfvars updates). Commit, push, open PR against master. CI MUST be green.
- [ ] T044 Squash-merge PR; delete branch; `git checkout master && git pull --ff-only`.
- [ ] T045 Pre-flight: `az vm run-command invoke -g rg-bld-shd-hub-npd-swc-001 -n vm-bld-shd-hub-npd-swc-001 --command-id RunShellScript --scripts "systemctl is-active actions.runner.*"` returns `active`.
- [ ] T046 Dispatch `deploy` workflow: `gh workflow run deploy.yaml -f service=vnet -f tenant=sp01 -f environment=npd -f action=apply -f apply=false` (PLAN-ONLY smoke test).
- [ ] T047 Inspect plan summary in the GH Actions UI; gate per FR-222 of feature 004 — adds are exclusively sp01 vnet resources (~10) + 25 dnslinks; zero hub-side changes.
- [ ] T048 Dispatch again with `apply=true` (operator-approval gate fires on `hub-npd` GH env protection); wait for green.
- [ ] T049 Validate: `az network vnet show -g rg-net-shd-sp01-npd-swc-001 -n vnet-net-shd-sp01-npd-swc-001 --query addressSpace.addressPrefixes -o tsv` returns `10.240.6.0/23`.
- [ ] T050 Validate dnslinks: `az network private-dns link vnet list --resource-group rg-dns-shd-hub-prd-swc-001 --zone-name privatelink.blob.core.windows.net --query "length([?virtualNetwork.id contains 'sp01'])"` returns `1` (the sp01 link exists).
- [ ] T051 Report sp01 plan + apply summaries and feature complete.

> Dependency chain: B (T001..T014) → T (T015..T018) → W-paper (T019..T020) → O (T022..T028, on operator wkst) → A (T029..T035, on operator wkst) → M (T036..T042, on operator wkst over Bastion) → W-merge (T043..T044) → D (T045..T051). T015..T018 parallelisable.
