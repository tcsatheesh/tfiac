# Tasks — Feature 109 (sp03/dev services instance)

- [X] T109-1 Author `variables/sp03/dev/services.tfvars.json` — services
  storage/keyvault/sql_server/data_factory; storage+keyvault PE toggles on;
  `private_endpoint_subnet_role = development`; vnet backend `sp03/npd/vnet.tfstate`;
  dns backend `hub/prd/dns.tfstate`.
- [X] T109-2 Register the tfvars path in `.github/workflows/services.yml`
  (pull_request + push triggers).
- [X] T109-3 Author `specs/109-sp03-dev-services/` artifacts.
- [ ] T109-4 Branch → PR → squash-merge → sync master.
- [ ] T109-5 Rollout prerequisites: hub `dns` applied (new zones); 108 sp03 vnet
  applied; `go-sqlcmd` present on the deploy runner.
- [ ] T109-6 Roll out: `gh workflow run deploy.yaml -f service=services -f
  tenant=sp03 -f environment=dev -f action=apply -f apply=true`; watch to green.

## Validation

- `terraform validate` (engine unchanged).
- Plan shows all services private (no public network access) + ADF managed PEs +
  linked services + SQL grant.
