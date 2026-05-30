# Shared fixtures referenced by other tests via `variables { ... }`
# blocks. This file itself contains no `run` blocks; importing it is
# implicit because terraform test loads every *.tftest.hcl in the
# directory and merges top-level `variables` defaults.

variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }
  services   = []
  children   = []
  extra_tags = {}
}
