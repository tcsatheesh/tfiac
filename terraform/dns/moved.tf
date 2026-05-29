###############################################################################
# terraform/dns/moved.tf  (feature 002 — T039)
#
# State migration from the legacy `module.dns` (raw azurerm_private_dns_zone
# `for_each` — see specs/002-private-dns-zones/legacy-state-inventory.txt)
# to the new engine-driven `module.dnszones` (AVM-wrapped per Constitution IX).
#
# ──────────────────────────────────────────────────────────────────────────
# STATUS: stub — populate from a real backend refresh before cut-over.
# ──────────────────────────────────────────────────────────────────────────
#
# Operator workflow (see specs/002-private-dns-zones/legacy-state-inventory.txt):
#
#   cd terraform/dns
#   terraform init -backend-config=<...>
#   terraform state list \
#     | grep -E '(azurerm_resource_group|azurerm_private_dns_zone)' \
#     > /tmp/inventory.txt
#
# Then, for each legacy address discovered, append a `moved` block here
# mapping it to the new canonical address. Note: the new addresses are
# AVM-wrapped (Constitution IX), so the right-hand side for zones is nested:
#
#   moved {
#     from = module.dns.azurerm_resource_group.this
#     to   = module.dnszones.azurerm_resource_group.this
#   }
#
#   moved {
#     from = module.dns.azurerm_private_dns_zone.this["privatelink.blob.core.windows.net"]
#     to   = module.dnszones.module.zone["blob"].azurerm_private_dns_zone.this
#   }
#
# After populating, run `terraform plan` and confirm:
#   - zero `azurerm_private_dns_zone` destroys
#   - the only changes are safe in-place tag reconciliations
#
# Until populated, the new stack will simply CREATE all 25 + custom zones.
# This is the correct behaviour for a greenfield deployment.
###############################################################################
