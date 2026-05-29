variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "dns"
    repo          = "tcsatheesh/tfiac"
  }
  services = [
    {
      service_type    = "private_dns_zone"
      service_purpose = "dns"
      key             = "blob"
      fqdn            = "privatelink.blob.core.windows.net"
    },
    {
      service_type    = "dns_zone"
      service_purpose = "dns"
      key             = "corp"
      fqdn            = "example.corp"
    },
  ]
  children = []
}

run "fqdn_used_verbatim_as_map_key" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "privatelink.blob.core.windows.net")
    error_message = "private_dns_zone FQDN must be the canonical name verbatim; got: ${jsonencode(keys(output.names))}"
  }

  assert {
    condition     = contains(keys(output.names), "example.corp")
    error_message = "dns_zone FQDN must be the canonical name verbatim."
  }

  assert {
    condition     = output.names["privatelink.blob.core.windows.net"].service_type == "private_dns_zone"
    error_message = "FQDN entry retains its service_type in the output."
  }

  # Baseline tags still apply to FQDN entries.
  assert {
    condition     = output.names["privatelink.blob.core.windows.net"].tags["managed_by"] == "terraform"
    error_message = "FQDN entry must still carry baseline tags."
  }
}

run "invalid_fqdn_uppercase_fails" {
  command = plan

  variables {
    services = [
      {
        service_type    = "private_dns_zone"
        service_purpose = "dns"
        key             = "bad"
        fqdn            = "PrivateLink.BLOB.Core.Windows.Net"
      },
    ]
  }

  expect_failures = [
    var.services,
  ]
}

run "fqdn_required_for_dns_zone" {
  command = plan

  variables {
    services = [
      {
        service_type    = "private_dns_zone"
        service_purpose = "dns"
        key             = "missing"
      },
    ]
  }

  expect_failures = [
    var.services,
  ]
}

run "fqdn_forbidden_for_non_dns" {
  command = plan

  variables {
    services = [
      {
        service_type    = "storage"
        service_purpose = "lgs"
        key             = "weird"
        fqdn            = "shouldnotbeset.example.com"
      },
    ]
  }

  expect_failures = [
    var.services,
  ]
}
