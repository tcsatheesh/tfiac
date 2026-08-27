locals {
  defaults = {
    # Azure SQL database defaults (dev-grade, cheapest DTU tier). Override per
    # instance via var.overrides (e.g. { database_sku_name = "GP_S_Gen5_2" }).
    database_sku_name       = "S0"
    database_collation      = "SQL_Latin1_General_CP1_CI_AS"
    database_max_size_gb    = 32
    database_zone_redundant = false
    server_version          = "12.0"
    minimum_tls_version     = "1.2"
  }

  config = merge(local.defaults, var.overrides)

  # sql_database (child, abbr `sqldb`, singleton) name derived locally from the
  # server canonical name — mirrors the reserved-child pattern used for PEs.
  database_name = "sqldb-${var.canonical_name}"

  # `private_endpoint` row (abbr `pep`) stays RESERVED in the engine; derive the
  # PE name in-module. `pep-${canonical_name}` is <= 80 chars (server <= 63).
  pe_name = "pep-${var.canonical_name}"
}
