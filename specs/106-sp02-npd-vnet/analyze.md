# Analyze — Feature 106 (sp02/npd vnet instance)

Cross-artifact consistency pass over [spec.md](./spec.md), [plan.md](./plan.md),
[tasks.md](./tasks.md) and the engine [004-vnet](../004-vnet/spec.md). No
BLOCKER/MAJOR findings outstanding.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| A-106-1 | MAJOR | Could a new spoke smuggle an engine change? | RESOLVED — only `specs/106-*`, `variables/sp02/npd/vnet.tfvars.json`, and the `vnet.yml` `paths:` list are touched. No `terraform/vnet/` or `modules/network/` edit. Honours `10n` ⇏ `00n`. |
| A-106-2 | BLOCKER | CIDR overlap would break hub peering / routing. | RESOLVED — `10.240.6.0/23` (`.6.0`–`.7.255`) is disjoint from sp01 `10.240.2.0/23` (`.2.0`–`.3.255`) and hub `10.240.4.0/23` (`.4.0`–`.5.255`). Verified in T-106-5. |
| A-106-3 | MAJOR | Subnet roles must exist in the engine catalogue. | RESOLVED — `development`, `pre-production`, `logic-app`, `function-app`, `preprod-logic`, `preprod-func`, `container-apps`, `agents` are all existing 004-vnet roles (same set sp01/npd selects). Instance only *selects* them. |
| A-106-4 | MAJOR | All subnet CIDRs must fall inside `address_space`. | RESOLVED — every subnet is within `10.240.6.0/23`; the engine's own validation also enforces this at plan time. Checked in T-106-5. |
| A-106-5 | MINOR | Dependency ordering must be explicit. | RESOLVED — spec + plan + tasks all state: hub vnet (101) → sp02 spoke vnet (106) → sp02 services (107); hub DNS already exists. |
| A-106-6 | MINOR | Secret handling. | RESOLVED — `subscription_id` is a runtime placeholder; the deploy workflow injects `secrets.AZURE_SUBSCRIPTION_ID`. No secret in repo. |
| A-106-7 | MINOR | CI must actually gate the new tfvars. | RESOLVED — T-106-2 adds the path to both `paths:` lists in `vnet.yml`; verified in T-106-6. |

**Conclusion:** consistent and ready to implement. The only deployable
artifact is the tfvars; the engine is untouched and its generic tests already
cover the spoke role.
