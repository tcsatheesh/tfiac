# T050 [US4] — FR-015 reserved-prefix / length tag-key violations

run "reject_microsoft_prefix" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "storage", count = 1 }]
      overrides = {
        "stsp01npduks001" = { tags = { "microsoft.cost" = "x" } }
      }
    }
  }
  expect_failures = [check.override_tag_keys_valid]
}

run "reject_azure_prefix" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "storage", count = 1 }]
      overrides = {
        "stsp01npduks001" = { tags = { "azure.foo" = "x" } }
      }
    }
  }
  expect_failures = [check.override_tag_keys_valid]
}

run "reject_windows_prefix" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "storage", count = 1 }]
      overrides = {
        "stsp01npduks001" = { tags = { "windows.bar" = "x" } }
      }
    }
  }
  expect_failures = [check.override_tag_keys_valid]
}

run "reject_overlong_key" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "storage", count = 1 }]
      overrides = {
        "stsp01npduks001" = { tags = {
          "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" = "x"
        } }
      }
    }
  }
  expect_failures = [check.override_tag_keys_valid]
}
