###############################################################################
# terraform/dns/moved.tf  (feature 002 — T039)
#
# State migration from the legacy module.dns (AVM-based) addresses to the
# new engine-driven module.dnszones addresses.
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
# mapping it to the new canonical address.
#
# Expected shape (one block per zone + one for the RG):
#
#   moved {
#     from = module.dns.azurerm_resource_group.avmrg
#     to   = module.dnszones.azurerm_resource_group.this
#   }
#
#   moved {
#     from = module.dns.module.private_dns_zones["blob"].azurerm_private_dns_zone.this
#     to   = module.dnszones.azurerm_private_dns_zone.this["blob"]
#   }
#
# After populating, run `terraform plan` and confirm:
#   - zero `azurerm_private_dns_zone` destroys
#   - the only changes are safe in-place tag reconciliations
#
# Until populated, the new stack will simply CREATE all 25 + custom zones.
# This is the correct behaviour for a greenfield deployment.
###############################################################################
