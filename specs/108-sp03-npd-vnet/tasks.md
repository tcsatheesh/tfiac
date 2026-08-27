# Tasks — Feature 108 (sp03/npd vnet instance)

- [X] T108-1 Author `variables/sp03/npd/vnet.tfvars.json` — spoke, `swc`, `shd`,
  address_space `10.240.8.0/23`, 8 subnets (dev/pre/logic/func/preprod-logic/
  preprod-func/container-apps/agents), `enable_spoke_nat_gateway = true`, hub +
  dns state backends.
- [X] T108-2 Register the tfvars path in `.github/workflows/vnet.yml`
  (pull_request + push triggers).
- [X] T108-3 Author `specs/108-sp03-npd-vnet/` artifacts (spec/plan/tasks/analyze).
- [ ] T108-4 Branch → PR → squash-merge → sync master.
- [ ] T108-5 Roll out: `gh workflow run deploy.yaml -f service=vnet -f tenant=sp03
  -f environment=npd -f action=apply -f apply=true`; watch to green.

## Validation

- `terraform validate` (engine unchanged; no local plan against real state).
- CIDR disjointness confirmed against the allocation table.
