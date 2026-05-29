# Naming Convention Engine - provider declarations
# =================================================
# This module is a pure HCL string/map transform. It creates no Azure
# resources and therefore declares NO `required_providers` block.
#
# This file exists solely to satisfy the repository's module-layout
# convention (Constitution v2.2.0, Principle VI), which requires every
# `modules/<service>/` to contain a `providers.tf` file.
#
# Consuming root stacks remain responsible for pinning their own
# `azurerm`, `azapi`, etc. providers in their own `providers.tf`.
