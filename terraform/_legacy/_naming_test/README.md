# `_naming_test` harness

This directory is a **non-stack** Terraform root used solely to render
`module.naming` for a `terraform plan` smoke check and as the consumer
in the determinism snapshot fixture.

It **MUST NOT** be iterated by environment variables, and it **MUST
NOT** be promoted to a landing-zone stack. Real consumer wiring is a
follow-on spec (see plan.md § Future Work).
