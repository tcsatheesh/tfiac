# terraform/rbac — Foundry RBAC engine stack (007-rbac)

Grants the Azure AI Foundry **account** and **project** system-assigned managed
identities the exact role-assignment matrix the Microsoft portal Standard-Agent
ARM template emits over the Foundry's bring-your-own (BYO) backings — Key Vault,
user-owned Storage, agent Storage, AI Search and Cosmos DB.

This stack creates **no** resources of its own beyond role assignments. It
consumes the `006-services` stack remote state to resolve the Foundry account,
project and every BYO target by `service_type` / `service_purpose`, reads the
account/project `principalId`s via `azapi` data sources, then fans the grants out
through `modules/rbac`.

## Inputs (`variables/<tenant>/<env>/rbac.tfvars.json`)

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `subscription_id` | string | — | Target subscription (provider + role-definition id scope). Injected by CI. |
| `services_state_backend` | object | — | azurerm backend of the consumed `006-services` state. |
| `enable_aifoundry_user_owned_storage` | bool | `false` | Gate the account MI Storage Blob Data Contributor grant (FR-049). |
| `enable_aifoundry_keyvault_connection` | bool | `false` | Gate the account MI Key Vault Crypto grants (FR-046/FR-047). |
| `agent_storage_purpose` | string\|null | `null` | `service_purpose` of the agent storage (project grants). |
| `account_storage_purpose` | string\|null | `null` | `service_purpose` of the account/user-owned storage (account grant); must differ from `agent_storage_purpose`. |

## Role matrix

See [specs/007-rbac/spec.md](../../specs/007-rbac/spec.md) (FR-046 … FR-058).
Account MI: KV Crypto Service Encryption User + KV Crypto User (gated) + RG
Contributor + user-owned Storage Blob Data Contributor (gated). Project MI: agent
Storage Blob Data Contributor/Owner + File Data Privileged Contributor, Search
Index Data Contributor + Search Service Contributor, Cosmos DB Operator +
DocumentDB Account Contributor + Cosmos DB Built-in Data Contributor (SQL).

## Testing

`terraform init -backend=false && terraform validate && terraform test`
(mocks the providers + overrides the services remote state; never a live
backend).
