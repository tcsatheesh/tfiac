from scripts.src.base import ImportStateBase


class ImportState(ImportStateBase):

    def __init__(
        self,
        *args,
        **kwargs,
    ):
        super().__init__(
            *args,
            **kwargs,
        )

    def _import(
        self,
    ):
        _logger = self._logger
        _logger.info("Importing state...")

        _vnet_variables = self._vnet_variables
        _remote_vnet_variables = self._remote_vnet_variables
        _firewall_variables = self._firewall_variables
        _dns_variables = self._dns_variables

        _vnet_subscription_id = _vnet_variables["subscription_id"]
        _vnet_resource_group_name = _vnet_variables["resource_group_name"]
        _vnet_name = _vnet_variables["name"]
        _route_table_name = _vnet_variables["route_table_name"]
        _remote_vnet_name = _remote_vnet_variables["name"]

        _logger.info(f"Importing resource group {_vnet_resource_group_name}...")
        self._import_resource_group(
            name="module.vnet.azurerm_resource_group.this",
            subscription_id=_vnet_subscription_id,
            resource_group_name=_vnet_resource_group_name,
        )
        _logger.info(f"Importing VNet {_vnet_name}...")
        self._import_resource(
            name="module.vnet.module.vnet.azapi_resource.vnet",
            subscription_id=_vnet_subscription_id,
            resource_group_name=_vnet_resource_group_name,
            resource_type="Microsoft.Network/virtualNetworks",
            resource=_vnet_name,
        )
        _logger.info(f"Importing diagnostics for VNet {_vnet_name} to log analytics...")
        self._import_resource(
            name='module.vnet.module.vnet.azurerm_monitor_diagnostic_setting.this["sendToLogAnalytics"]',
            subscription_id=_vnet_subscription_id,
            resource_group_name= _vnet_resource_group_name,
            resource_type="Microsoft.Network/virtualNetworks",
            resource=f"/{_vnet_name}|sendToLogAnalytics",
        )
        _logger.info(f"Importing VNet route table {_route_table_name}...")
        self._import_resource(
            name="module.vnet.azurerm_route_table.this",
            subscription_id=_vnet_subscription_id,
            resource_group_name=_vnet_resource_group_name,
            resource_type="Microsoft.Network/routeTables",
            resource=_route_table_name,
        )

        _dns_subscription_id = _dns_variables["subscription_id"]
        _dns_resource_group_name = _dns_variables["resource_group_name"]

        for _key2, _value2 in _dns_variables["domain_names"].items():
            _logger.info(f"Importing virtual link to DNS key {_key2} value {_value2}")
            self._import_resource(
                name=f'module.vnet.azurerm_private_dns_zone_virtual_network_link.this["{_key2}"]',
                subscription_id=_dns_subscription_id,
                resource_group_name=_dns_resource_group_name,
                resource_type=f"Microsoft.Network/privateDnsZones",
                resource=f"{_value2}/virtualNetworkLinks/{_vnet_name}",
            )

        for _key, _value in _vnet_variables["subnets"].items():
            _logger.debug(f"{_key}: {_value}")
            _nsg_name = _value["nsg"]
            _subnet_name = _value["name"]
            if _value["add_nsg"]:
                _logger.info(
                    f"Importing VNet {_vnet_name} key {_subnet_name} nsg {_nsg_name}..."
                )
                self._import_resource(
                    name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_group.this',
                    subscription_id=_vnet_subscription_id,
                    resource_group_name=_vnet_resource_group_name,
                    resource_type="Microsoft.Network/networkSecurityGroups",
                    resource=_nsg_name,
                )
            else:
                _logger.info(
                    f"No NSG to import for subnet {_subnet_name} and nsg {_nsg_name}"
                )
            _logger.info(f"Importing VNet {_vnet_name} subnet {_subnet_name}...")
            self._import_resource(
                name=f'module.vnet.module.subnets["{_key}"].azapi_resource.subnet',
                subscription_id=_vnet_subscription_id,
                resource_group_name=_vnet_resource_group_name,
                resource_type="Microsoft.Network/virtualNetworks",
                resource=f"{_vnet_name}/subnets/{_subnet_name}",
            )
            if _value["has_nsg_rules"]:
                _logger.info(
                    f"Importing NSG rules for subnet {_subnet_name} and nsg {_nsg_name}"
                )
                # for _key1, _value1 in _value["nsg_rules"].items():
                #     _logger.info(f"Importing nsg rule {_key1}")
                #     self._import_resource(
                #         name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_rule.this["{_key1}"]',
                #         subscription_id=_vnet_subscription_id,
                #         resource_group_name=_vnet_resource_group_name,
                #         resource_type="Microsoft.Network/networkSecurityGroups",
                #         resource=f'{_nsg_name}/securityRules/{_value1["name"]}',
                #     )
            else:
                _logger.info(
                    f"No NSG rules to import for subnet {_subnet_name} and nsg {_nsg_name}"
                )

        if "vnet_peering" in _vnet_variables:
            _remote_vnet_subscription_id = _remote_vnet_variables["subscription_id"]
            _remote_vnet_resource_group_name = _remote_vnet_variables[
                "resource_group_name"
            ]
            _logger.info(
                f"Importing VNet peering {_vnet_variables['vnet_peering']['local_name']}..."
            )
            self._import_resource(
                name="module.vnet.module.peering[0].azapi_resource.this[0]",
                subscription_id=_vnet_subscription_id,
                resource_group_name=_vnet_resource_group_name,
                resource_type="Microsoft.Network/virtualNetworks",
                resource=f'{_vnet_name}/virtualNetworkPeerings/{_vnet_variables["vnet_peering"]["local_name"]}',
            )
            _logger.info(
                f"Importing VNet peering {_vnet_variables['vnet_peering']['remote_name']}..."
            )
            self._import_resource(
                name="module.vnet.module.peering[0].azapi_resource.reverse[0]",
                subscription_id=_remote_vnet_subscription_id,
                resource_group_name=_remote_vnet_resource_group_name,
                resource_type="Microsoft.Network/virtualNetworks",
                resource=f'{_remote_vnet_name}/virtualNetworkPeerings/{_vnet_variables["vnet_peering"]["remote_name"]}',
            )

        if "vnet_peering" not in _vnet_variables:
            _firewall_subscription_id = _firewall_variables["subscription_id"]
            _firewall_resource_group_name = _firewall_variables["resource_group_name"]
            _firewall_name = _firewall_variables["name"]
            _logger.info("Importing firewall...")
            _firewall_name = _firewall_variables["name"]
            _firewall_policy_name = _firewall_variables["policy"]["name"]
            _logger.info(f"Importing firewall {_firewall_name}...")
            self._import_resource(
                name="module.vnet.module.firewall[0].module.firewall.azurerm_firewall.this",
                subscription_id=_firewall_subscription_id,
                resource_group_name=_firewall_resource_group_name,
                resource_type="Microsoft.Network/azureFirewalls",
                resource=_firewall_name,
            )
            _logger.info(f"Importing firewall policy {_firewall_policy_name}...")
            self._import_resource(
                name="module.vnet.module.firewall[0].module.fwpolicy.azurerm_firewall_policy.this",
                subscription_id=_firewall_subscription_id,
                resource_group_name=_firewall_resource_group_name,
                resource_type="Microsoft.Network/firewallPolicies",
                resource=_firewall_policy_name,
            )
            _logger.info(
                f"Importing firewall public IP {_firewall_variables['public_ip_name']}..."
            )
            self._import_resource(
                name="module.vnet.module.firewall[0].module.fw_public_ip.azurerm_public_ip.this",
                subscription_id=_firewall_subscription_id,
                resource_group_name=_firewall_resource_group_name,
                resource_type="Microsoft.Network/publicIPAddresses",
                resource=f'{_firewall_variables["public_ip_name"]}',
            )
            _logger.info(
                f"Importing firewall management public IP {_firewall_variables['management']['public_ip_name']}..."
            )
            self._import_resource(
                name="module.vnet.module.firewall[0].module.fw_managment_public_ip.azurerm_public_ip.this",
                subscription_id=_firewall_subscription_id,
                resource_group_name=_firewall_resource_group_name,
                resource_type="Microsoft.Network/publicIPAddresses",
                resource=f'{_firewall_variables["management"]["public_ip_name"]}',
            )
            _logger.info(f"Importing firewall diagnostics...")
            _firewall_diagnostics_name = _firewall_variables["diagnostic_settings"]["name"]
            self._import_resource(
                name=f'module.vnet.module.firewall[0].module.firewall.azurerm_monitor_diagnostic_setting.this["{_firewall_diagnostics_name}"]',
                subscription_id=_firewall_subscription_id,
                resource_group_name=_firewall_resource_group_name,
                resource_type="Microsoft.Network/azureFirewalls",
                resource=f"{_firewall_name}|diag",
            )

            for _key, _value in _firewall_variables["ipgroups"].items():
                _ip_group_name = _value["name"]
                _logger.info(f"Importing firewall IPGroup {_ip_group_name}...")
                self._import_resource(
                    name=f'module.vnet.module.firewall[0].azurerm_ip_group.this["{_ip_group_name}"]',
                    subscription_id=_firewall_subscription_id,
                    resource_group_name=_firewall_resource_group_name,
                    resource_type="Microsoft.Network/ipGroups",
                    resource=_ip_group_name,
                )

            for _key_rcg, _value_rcg in _firewall_variables["rulecollections"].items():
                _rcg_name = _value_rcg["name"]
                _logger.info(
                    f"Importing firewall policy rule collection group key {_key_rcg} value {_rcg_name}"
                )
                self._import_resource(
                    name=f"module.vnet.module.firewall[0].module.{_key_rcg}.azurerm_firewall_policy_rule_collection_group.this",
                    subscription_id=_firewall_subscription_id,
                    resource_group_name=_firewall_resource_group_name,
                    resource_type="Microsoft.Network/firewallPolicies",
                    resource=f"{_firewall_policy_name}/ruleCollectionGroups/{_rcg_name}",
                )
            _key_rcg = "denyall"
            _rcg_name = "DenyAllInternetCollectionGroup"
            _logger.info(
                f"Importing firewall policy rule collection group key {_key_rcg} value {_rcg_name}"
            )
            self._import_resource(
                name=f"module.vnet.module.firewall[0].module.{_key_rcg}.azurerm_firewall_policy_rule_collection_group.this",
                subscription_id=_firewall_subscription_id,
                resource_group_name=_firewall_resource_group_name,
                resource_type="Microsoft.Network/firewallPolicies",
                resource=f"{_firewall_policy_name}/ruleCollectionGroups/{_rcg_name}",
            )


if __name__ == "__main__":
    _import_state = ImportState()
    _import_state._import()
