# T016 [US1] — positive_regions
# Exercise every day-one region; assert the short code appears in
# emitted names exactly as catalogued (FR-010).

run "uksouth" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  assert {
    condition     = contains(keys(output.names), "vnet-sp01-npd-uks-001")
    error_message = "uksouth → uks short code missing."
  }
}

run "westus2" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "westus2"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  assert {
    condition     = contains(keys(output.names), "vnet-sp01-npd-wus2-001")
    error_message = "westus2 → wus2 short code missing."
  }
}

run "westeurope" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "westeurope"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  assert {
    condition     = contains(keys(output.names), "vnet-sp01-npd-weu-001")
    error_message = "westeurope → weu short code missing."
  }
}

run "eastus2" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "eastus2"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  assert {
    condition     = contains(keys(output.names), "vnet-sp01-npd-eus2-001")
    error_message = "eastus2 → eus2 short code missing."
  }
}
