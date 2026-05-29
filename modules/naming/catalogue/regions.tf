# Region catalogue - maps CAF short region codes to full Azure region names.
#
# Short code is used inside resource names (per spec.md "Inputs" table).
# Full name is used as the value of the baseline `region` tag (per spec.md
# "Baseline Tags").
#
# Adding a region: append the short-code -> full-name pair below. Short
# codes MUST be lowercase, 3-4 chars, and match the CAF abbreviation
# (https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).

locals {
  regions = {
    # Europe
    uks  = "uksouth"
    ukw  = "ukwest"
    weu  = "westeurope"
    neu  = "northeurope"
    fc   = "francecentral"
    fs   = "francesouth"
    sn   = "switzerlandnorth"
    sw   = "switzerlandwest"
    gwc  = "germanywestcentral"
    nwe  = "norwayeast"
    swc  = "swedencentral"

    # Americas
    eus  = "eastus"
    eus2 = "eastus2"
    cus  = "centralus"
    ncus = "northcentralus"
    scus = "southcentralus"
    wus  = "westus"
    wus2 = "westus2"
    wus3 = "westus3"
    cnc  = "canadacentral"
    cne  = "canadaeast"
    brs  = "brazilsouth"

    # Asia Pacific
    eas  = "eastasia"
    sea  = "southeastasia"
    jpe  = "japaneast"
    jpw  = "japanwest"
    krc  = "koreacentral"
    krs  = "koreasouth"
    auc  = "australiacentral"
    aue  = "australiaeast"
    ause = "australiasoutheast"
    cin  = "centralindia"
    sin  = "southindia"
    win  = "westindia"

    # Middle East & Africa
    uaen = "uaenorth"
    uaec = "uaecentral"
    san  = "southafricanorth"
    saw  = "southafricawest"
  }
}
