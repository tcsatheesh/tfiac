# terraform/bootstrap - hub-internal Terraform state SA (feature 000)

This stack is the **chicken-and-egg solver** for the repo. It creates:

| Resource | Name |
|----------|------|
| Resource Group | `rg-tfs-shd-hub-npd-swc-001` |
| Storage Account | `sttfsshdhubnpdswc001` (AAD-only, PE-only) |
| Blob Container | `tfstate` |
| Private Endpoint | `pep-st-tfs-shd-hub-npd-swc-001-blob-001` in hub vnet `development` subnet |
| Private DNS A-record | `sttfsshdhubnpdswc001.privatelink.blob.core.windows.net` |
| RBAC | operator → Storage Blob Data Owner; hub build VM MI + GH OIDC SP → Storage Blob Data Contributor |

It is **run once, locally**, from the operator workstation. State is local
(see `backend.tf` and `.gitignore`). After this apply, every other stack
re-inits against the new SA via `variables/backend.hcl` (FR-010).

## One-shot run

```bash
# 0. Authenticate.
az login
az account set --subscription 883c9081-23ed-4674-95c5-45c74834e093

# 1. Open the LEGACY state SA firewall briefly (data.tf reads upstream
#    state from it). Pattern mirrors feature 004 Phase 8.
OPERATOR_IP=$(curl -s https://api.ipify.org)
az storage account network-rule add \
  -g stcwe-rg-tfs-01 -n stcwetfstate01 --ip-address "$OPERATOR_IP"
az storage account update -g stcwe-rg-tfs-01 -n stcwetfstate01 \
  --public-network-access Enabled

# 2. Populate terraform.tfvars (gitignored) with the OIDC SP object id
#    once it exists (see plan.md §5). At first apply leave it null.
cat > terraform.tfvars <<EOF
subscription_id    = "883c9081-23ed-4674-95c5-45c74834e093"
operator_object_id = "$(az ad signed-in-user show --query id -o tsv)"
gh_oidc_object_id  = null   # set after Phase O
EOF

# 3. Plan + apply.
rm -rf .terraform
terraform init
terraform plan -var-file=terraform.tfvars -out bootstrap.tfplan
terraform apply bootstrap.tfplan

# 4. Re-lock legacy SA firewall.
az storage account network-rule remove \
  -g stcwe-rg-tfs-01 -n stcwetfstate01 --ip-address "$OPERATOR_IP"
az storage account update -g stcwe-rg-tfs-01 -n stcwetfstate01 \
  --public-network-access Disabled

# 5. Smoke test via Bastion -> build VM:
#    az storage blob list --account-name sttfsshdhubnpdswc001 \
#      --container-name tfstate --auth-mode login
```

## Re-apply with OIDC SP

After Phase O has provisioned `gh-oidc-tfiac-hub-npd`:

```bash
SP_OBJ_ID=$(az ad sp show --id "$(az ad app list --display-name gh-oidc-tfiac-hub-npd --query '[0].appId' -o tsv)" --query id -o tsv)
sed -i "s/gh_oidc_object_id  = null/gh_oidc_object_id  = \"$SP_OBJ_ID\"/" terraform.tfvars
terraform plan -var-file=terraform.tfvars -out bootstrap.tfplan   # +1 role assignment
terraform apply bootstrap.tfplan
```

## Notes

- **Never** commit `terraform.tfvars` or `terraform.tfstate*` — `.gitignore`
  enforces.
- The legacy SA `stcwetfstate01` is **untouched** by this stack (FR-008).
- All resource names come from `modules/naming` (FR-004); see
  `specs/001-naming-convention-engine/`.
