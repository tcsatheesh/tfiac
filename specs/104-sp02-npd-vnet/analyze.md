# Analyze — 104-sp02-npd-vnet

Cross-artifact consistency pass (`spec.md` ↔ `plan.md` ↔ `tasks.md` ↔ tfvars ↔
CLAUDE.md standing rules).

## Findings

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A1 | — | spec, plan, tasks agree: new `10n` instance of 004-vnet (spoke), zero engine changes. | Consistent. |
| A2 | BLOCKER | Does `address_space` overlap any existing allocation? hub=`10.240.4.0/23` (.4–.5), sp01=`10.240.2.0/23` (.2–.3). | RESOLVED: sp02=`10.240.6.0/23` (.6–.7) is disjoint from both. (FR-104-05, C-104-01) |
| A3 | MAJOR | Does this require an engine change (would violate `10n` ⇏ `00n`)? | RESOLVED: NO. All eight roles (development, pre-production, logic-app, function-app, preprod-logic, preprod-func, container-apps, agents) already exist in the 004-vnet catalogue; the instance only *selects* them. (FR-104-01, C-104-03) |
| A4 | MAJOR | "Register its virtual link and peer" — are these new code? | RESOLVED: NO. Engine `terraform/vnet/dns.tf` registers the private-DNS-zone vnet-link from `dns_state_backend`; engine `module.peering` creates hub⇄spoke peering from `hub_state_backend`. Both are existing spoke behaviours. (FR-104-03/04, C-104-03) |
| A5 | MAJOR | New spoke = new `10n` folder, or amendment to 102? | RESOLVED: NEW instance feature (new `sp02` tenant) per CLAUDE.md "Adding a new spoke … = a NEW instance feature". New `specs/104-*/` + new tfvars + one CI line. (C-104-04) |
| A6 | MINOR | Is `sp02` a valid tenant for the engine + dispatch? | RESOLVED: engine `tenant` regex `^(hub|sp[0-9]{2})$` accepts `sp02`; `deploy.yaml` already lists `sp02`. Only `vnet.yml` `paths:` needs the new tfvars line. (C-104-06) |
| A7 | MINOR | Subnet map masks fit inside `10.240.6.0/23`? | RESOLVED: yes — same masks as sp01 (verified-good) shifted by +4 in the third octet; `agents 10.240.7.0/24` occupies the upper half, container-apps + the six smaller subnets fit the lower `/24`. (C-104-02) |
| A8 | INFO | tfvars `dns_state_backend.key` ends `.tfstate` and `subscription_id` is a GUID (engine validations). | Consistent (`hub/prd/dns.tfstate`, GUID present). |
| A9 | INFO | Spec pinned-params, plan A1–A5, tasks T001–T008, tfvars all agree on `/23` + the eight-role map. | Consistent. |
| A10 | INFO | Rollout ordering (hub → sp02 spoke) explicit; live apply via workflow only; no SA-firewall change. | Consistent with CLAUDE.md. |

## Constitution / standing-rule check
- ✅ `10n` instance feature; does NOT alter the `00n` engine.
- ✅ New spoke is a new `10n` instance (not a 102 amendment).
- ✅ Address space non-overlapping (hub/sp01/sp02 disjoint `/23`s).
- ✅ Private-by-default unaffected (vnet stack; spoke routes via hub firewall).
- ✅ Live rollout via GitHub `deploy` workflow only; never local apply; never
  open the tfstate SA firewall.

**Result: no unresolved BLOCKER/MAJOR findings. Ready to implement (rollout
operator-run via workflow, not this PR).**
