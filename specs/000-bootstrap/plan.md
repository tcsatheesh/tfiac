# Feature 000 — Bootstrap state SA — Implementation Plan

## §1. Architecture overview

```
operator workstation                               GitHub Actions
  │                                                 │
  │ (one-time)                                      │ (per dispatch, OIDC → sub 883c…)
  ▼                                                 ▼
terraform/bootstrap/  ───local state───►   sttfsshdhubnpdswc001 (hub-internal)
   │                                          ▲
   │                                          │ Private Endpoint
   │                                          │ in dev subnet 10.240.4.0/26
   │                                          │
   ├── data.tfr_state.dns  (one-time read)    │
   ├── data.tfr_state.vnet (one-time read)    │
   ├── data.azurerm_linux_vm (build VM)       │
   │                                          │
   ▼                                          │
creates:                                      │
  rg-tfs-shd-hub-npd-swc-001                  │
  sttfsshdhubnpdswc001  ───────────────►──────┘
  container "tfstate"
  PE → dev subnet
  A-record in privatelink.blob.* zone
  RBAC: operator (Owner), build VM MI (Contrib), GH SP (Contrib)
```

Every other stack thereafter inits against the new backend via
`variables/backend.hcl` (updated in-place) + per-stack `-backend-config=key=<tenant>/<env>/<service>.tfstate`. CI on the hub
build VM (self-hosted runner) reaches the SA via the PE; no firewall
poke needed.

## §2. Bootstrap stack layout

```
terraform/bootstrap/
├── providers.tf      # azurerm + azuread, sub-aware
├── backend.tf        # LOCAL backend (explicit, with a banner comment)
├── data.tf           # data.tfr_state.dns + data.tfr_state.vnet
│                     # data.azurerm_linux_virtual_machine.build_vm
│                     # data.azurerm_client_config.current
├── locals.tf         # naming inputs
├── main.tf           # naming module + rg + sa + container + PE + A-record + RBAC
├── variables.tf      # subscription_id, operator_object_id (null-able),
│                     # gh_oidc_object_id (null-able)
├── outputs.tf        # sa_id, sa_name, rg_name, container_name, pe_ip, a_record_fqdn
├── README.md         # one-shot run instructions
└── .gitignore        # terraform.tfstate*  .terraform/
```

## §3. New backend.hcl

```hcl
# variables/backend.hcl (replaces the legacy stcwetfstate01 entries)
resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
storage_account_name = "sttfsshdhubnpdswc001"
container_name       = "tfstate"
use_azuread_auth     = true
subscription_id      = "883c9081-23ed-4674-95c5-45c74834e093"
```

Per-stack `init` invocation pattern:

```bash
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=hub/npd/vnet.tfstate"
```

## §4. Migration mechanism (per stack)

```bash
cd terraform/<stack>
# 1. snapshot existing state for safety
cp .terraform/terraform.tfstate /tmp/<stack>-tfstate-$(date +%s).bak
terraform state pull > /tmp/<stack>-snapshot-$(date +%s).json

# 2. point at NEW backend (still local .terraform; -migrate-state copies blob)
terraform init -migrate-state -force-copy \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=<tenant>/<env>/<stack>.tfstate"

# 3. verify
terraform plan -no-color -input=false \
  -var-file=../../variables/<tenant>/<env>/<stack>.tfvars.json \
  -var subscription_id=883c9081-23ed-4674-95c5-45c74834e093
# Expected: No changes. Your infrastructure matches the configuration.
```

Migration order (C-009): dns → vnet (hub) → log → buildsvr.

## §5. Self-bootstrap of GH OIDC (T-OIDC)

```bash
# 1. App registration + SP (idempotent — name unique)
APP_NAME="gh-oidc-tfiac-hub-npd"
APP_ID=$(az ad app create --display-name "$APP_NAME" \
  --query appId -o tsv)
az ad sp create --id "$APP_ID" -o none

# 2. Federated credential — scoped to GH environment (NOT branch)
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name":"hub-npd-environment",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:tcsatheesh/tfiac:environment:hub-npd",
  "audiences":["api://AzureADTokenExchange"]
}'

# 3. Subscription-level Contributor (least privilege we can afford for IaC apply)
SP_OBJ_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
az role assignment create --assignee-object-id "$SP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/883c9081-23ed-4674-95c5-45c74834e093"

# 4. GH environment + secrets
gh api -X PUT "repos/tcsatheesh/tfiac/environments/hub-npd" \
  -f wait_timer=0 -F prevent_self_review=false \
  -f deployment_branch_policy[protected_branches]=true \
  -f deployment_branch_policy[custom_branch_policies]=false
gh secret set AZURE_CLIENT_ID       --env hub-npd --body "$APP_ID"
gh secret set AZURE_TENANT_ID       --env hub-npd --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --env hub-npd --body "883c9081-23ed-4674-95c5-45c74834e093"

# 5. Feed the SP object id BACK into the bootstrap stack's tfvars so it
#    gets Storage Blob Data Contributor on the new SA.
echo "$SP_OBJ_ID"  # paste into terraform/bootstrap/terraform.tfvars
```

This runs once from the operator workstation as part of T-OIDC.

## §6. Workflow rewrite

`.github/workflows/deploy.yaml` (REPLACES `deploy_all.yaml`):

```yaml
name: deploy
on:
  workflow_dispatch:
    inputs:
      service:     { required: true, type: choice, options: [vnet, dns, log, buildsvr] }
      tenant:      { required: true, type: choice, options: [hub, sp01, sp02] }
      environment: { required: true, type: choice, options: [npd, prd], default: npd }
      action:      { required: true, type: choice, options: [apply, destroy], default: apply }
      apply:       { required: true, type: boolean, default: false }
permissions: { id-token: write, contents: read }
jobs:
  plan:
    runs-on: [self-hosted, hub-npd]   # build VM
    environment: hub-npd              # static — matches federated credential subject (C-014)
    outputs: { exitcode: ${{ steps.tfp.outputs.exitcode }} }
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: 1.9.8, terraform_wrapper: false }
      - name: init
        working-directory: terraform/${{ inputs.service }}
        run: |
          terraform init -reconfigure \
            -backend-config=../../variables/backend.hcl \
            -backend-config="key=${{ inputs.tenant }}/${{ inputs.environment }}/${{ inputs.service }}.tfstate"
      - id: tfp
        name: plan
        working-directory: terraform/${{ inputs.service }}
        env: { ARM_USE_OIDC: "true" }
        run: |
          set +e
          terraform plan -no-color -input=false \
            -var-file=../../variables/${{ inputs.tenant }}/${{ inputs.environment }}/${{ inputs.service }}.tfvars.json \
            -var subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }} \
            -detailed-exitcode -out tfplan
          echo "exitcode=$?" >> $GITHUB_OUTPUT
      - uses: actions/upload-artifact@v4
        with: { name: tfplan-${{ inputs.tenant }}-${{ inputs.environment }}-${{ inputs.service }}, path: terraform/${{ inputs.service }}/tfplan }
  apply:
    needs: plan
    if: inputs.apply && inputs.action == 'apply' && needs.plan.outputs.exitcode == '2'
    runs-on: [self-hosted, hub-npd]
    environment: hub-npd
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: 1.9.8, terraform_wrapper: false }
      - uses: actions/download-artifact@v4
        with: { name: tfplan-${{ inputs.tenant }}-${{ inputs.environment }}-${{ inputs.service }}, path: terraform/${{ inputs.service }}/ }
      - name: init
        working-directory: terraform/${{ inputs.service }}
        run: |
          terraform init -reconfigure \
            -backend-config=../../variables/backend.hcl \
            -backend-config="key=${{ inputs.tenant }}/${{ inputs.environment }}/${{ inputs.service }}.tfstate"
      - name: apply
        working-directory: terraform/${{ inputs.service }}
        env: { ARM_USE_OIDC: "true" }
        run: terraform apply -no-color -input=false tfplan
```

Notes:
- Uses `actions/upload-artifact@v4` / `download-artifact@v4` (v3 deprecation
  documented).
- Self-hosted runner label `hub-npd` (must exist on the build VM; verified in T-Verify).
- Backend key derived from inputs deterministically.

## §7. Testing strategy

The bootstrap stack ships `terraform/bootstrap/tests/` with:

- `plan_creates_minimum_resources.tftest.hcl` — `command = plan`,
  mocks providers, asserts plan contains exactly: 1 RG, 1 SA, 1 container,
  1 PE, 1 A-record, 3 role assignments (when both operator + gh_oidc set).
- `aad_only_enforced.tftest.hcl` — asserts `shared_access_key_enabled == false`,
  `default_to_oauth_authentication == true`, `public_network_access_enabled == false`.
- `pe_subnet_correct.tftest.hcl` — asserts PE subnet id matches dev subnet output.

CI: extend the existing `terraform/vnet` CI pattern with a new
`bootstrap fmt / validate / test` job in `.github/workflows/bootstrap.yml`
(modules-style, fmt+init -backend=false+validate+test only — never plans
against real Azure in CI).

## §8. Rollout (live ops)

1. T-OIDC: self-bootstrap GH OIDC SP + secrets + GH env from operator workstation.
2. T-Boot-Apply: from operator workstation, open legacy SA firewall → `terraform init` (legacy backend, in-place; the bootstrap stack only `data.terraform_remote_state` reads it) → `terraform apply` → re-lock legacy SA firewall.
3. T-Migrate-dns: open legacy SA firewall once more → `terraform init -migrate-state` for dns → verify `No changes` → re-lock legacy SA firewall. *(Migration source = legacy SA, target = new SA. Both need read; the new SA is reached via the PE from the operator workstation through Bastion.)*
4. T-Migrate-vnet-hub: same for vnet (hub key `hub/npd/vnet.tfstate`).
5. T-Migrate-log: same for log.
6. T-Migrate-buildsvr: same for buildsvr.
7. T-Workflow-Up: PR + merge the new deploy workflow.
8. T-Sp01-Deploy: dispatch `(service=vnet, tenant=sp01, environment=npd, apply=true)` from GH Actions UI; gate is `Plan: N to add, 0 to change, 0 to destroy` where adds are exclusively spoke resources.

## §9. Risks + mitigations

| Risk | Mitigation |
|---|---|
| Operator workstation cannot reach PE-only SA after bootstrap | Operator runs `terraform init` over Bastion → build VM SSH session, not directly. Documented in `terraform/bootstrap/README.md`. |
| State migration corrupts state | Per-stack snapshot to `/tmp` before migrate (C-010). Verified `plan == No changes` post-migration before next stack. |
| GH OIDC misconfigured → workflow auth fails | T-OIDC ends with a smoke-test dispatch (a no-op `plan` job against dns) before T-Workflow-Up is merged. |
| Build VM MI lacks roles | Bootstrap stack assigns Storage Blob Data Contributor explicitly; `data.azurerm_linux_virtual_machine` lookup is hard-coded to the known fixture. |
| Self-hosted runner offline at sp01 deploy time | Pre-flight `az vm run-command invoke ... systemctl status actions.runner.*` before dispatch. |
| Legacy SA's regional pair of `Microsoft.Storage` SE locations conflicts | Not applicable — legacy SA is the source only during the brief migration window and is read over public internet + operator IP whitelist; SEs are irrelevant. |

## §10. Constitution compliance

- I (Variables-not-hard-coded): operator object id + gh oidc object id passed via variables; only the build VM RG/name is hard-coded (stable fixture, not an environment variable).
- II (Defaults preserve behaviour): operator_object_id default = null → no role assignment, no behaviour change for CI-only mode.
- III (Validation at boundaries): variables.tf has `validation` blocks for the two object ids (GUID format, null-allowed).
- IV (Tests for every new variable + path): three `.tftest.hcl` files cover the resource shape and the AAD-only invariant.
- V (`terraform fmt -recursive` + `terraform test` green pre-merge): enforced by new bootstrap CI workflow.
