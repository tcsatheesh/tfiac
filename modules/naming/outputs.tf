output "names" {
  description = "Flat map of every canonical resource name produced for this batch (FR-031)."
  value       = local.emitted
}

output "by_type" {
  description = "Convenience index: service_type → list of canonical names."
  value = {
    for t in toset([for n, r in local.emitted : r.service_type]) :
    t => sort([for n, r in local.emitted : n if r.service_type == t])
  }
}
