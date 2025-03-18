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

        _logger.info(f"Importing resource group {_vnet_resource_group_name}...")
        self._import_resource(
            name="module.vnet.azurerm_resource_group.this",
            resource_id=f"/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}",
        )
        _logger.info(f"Importing VNet {_vnet_name}...")
        self._import_resource(
            name="module.vnet.module.vnet.azapi_resource.vnet",
            resource_id=f"/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_name}",
        )
        _logger.info(f"Importing diagnostics for VNet {_vnet_name} to log analytics...")
        self._import_resource(
            name='module.vnet.module.vnet.azurerm_monitor_diagnostic_setting.this["sendToLogAnalytics"]',
            resource_id=f"/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_name}|sendToLogAnalytics",
        )
        _logger.info(f"Importing VNet route table {_route_table_name}...")
        self._import_resource(
            name="module.vnet.azurerm_route_table.this",
            resource_id=f"/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/routeTables/{_route_table_name}",
        )

        for _key, _value in _vnet_variables["subnets"].items():
            _logger.debug(f"{_key}: {_value}")
            _nsg_name = _value["nsg"]
            _subnet_name = _value["name"]
            _logger.info(
                f"Importing VNet {_vnet_name} key {_subnet_name} nsg {_nsg_name}..."
            )
            self._import_resource(
                name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_group.this',
                resource_id=f"/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/networkSecurityGroups/{_nsg_name}",
            )
            _logger.info(f"Importing VNet {_vnet_name} subnet {_subnet_name}...")
            self._import_resource(
                name=f'module.vnet.module.subnets["{_key}"].azapi_resource.subnet',
                resource_id=f"/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_name}/subnets/{_subnet_name}",
            )
            for _key1, _value1 in _value["nsg_rules"].items():
                _logger.info(f"Importing nsg rule {_key1}")
                self._import_resource(
                    name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_rule.this["{_key1}"]',
                    resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/networkSecurityGroups/{_nsg_name}/securityRules/{_value1["name"]}',
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
                resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_name}/virtualNetworkPeerings/{_vnet_variables["vnet_peering"]["local_name"]}',
            )
            _logger.info(
                f"Importing VNet peering {_vnet_variables['vnet_peering']['remote_name']}..."
            )
            self._import_resource(
                name="module.vnet.module.peering[0].azapi_resource.reverse[0]",
                resource_id=f'/subscriptions/{_remote_vnet_subscription_id}/resourceGroups/{_remote_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_remote_vnet_name}/virtualNetworkPeerings/{_vnet_variables["vnet_peering"]["remote_name"]}',
            )

        if "vnet_peering" not in _vnet_variables:
            _firewall_subscription_id = _firewall_variables["subscription_id"]
            _firewall_resource_group_name = _firewall_variables["resource_group_name"]
            _firewall_name = _firewall_variables["name"]
            _logger.info("Importing firewall...")
            _firewall_name = _firewall_variables["name"]
            _logger.info(f"Importing firewall {_firewall_name}...")
            self._import_resource(
                name="module.vnet.module.firewall[0].azurerm_firewall.this",
                resource_id=f"/subscriptions/{_firewall_subscription_id}/resourceGroups/{_firewall_resource_group_name}/providers/Microsoft.Network/azureFirewalls/{_firewall_name}",
            )
            _logger.info(
                f"Importing firewall policy {_firewall_variables['policy']['name']}..."
            )
            self._import_resource(
                name="module.vnet.module.fwpolicy[0].azurerm_firewall_policy.this",
                resource_id=f'/subscriptions/{_firewall_subscription_id}/resourceGroups/{_firewall_resource_group_name}/providers/Microsoft.Network/firewallPolicies/{_firewall_variables["policy"]["name"]}',
            )
            _logger.info(
                f"Importing firewall public IP {_firewall_variables['public_ip_name']}..."
            )
            self._import_resource(
                name="module.vnet.module.fw_public_ip[0].azurerm_public_ip.this",
                resource_id=f'/subscriptions/{_firewall_subscription_id}/resourceGroups/{_firewall_resource_group_name}/providers/Microsoft.Network/publicIPAddresses/{_firewall_variables["public_ip_name"]}',
            )
            _logger.info(
                f"Importing firewall management public IP {_firewall_variables['management']['public_ip_name']}..."
            )
            self._import_resource(
                name="module.vnet.module.fw_managment_public_ip[0].azurerm_public_ip.this",
                resource_id=f'/subscriptions/{_firewall_subscription_id}/resourceGroups/{_firewall_resource_group_name}/providers/Microsoft.Network/publicIPAddresses/{_firewall_variables["management"]["public_ip_name"]}',
            )
            _logger.info(f"Importing firewall diagnostics...")
            self._import_resource(
                name='module.vnet.module.firewall[0].azurerm_monitor_diagnostic_setting.this["to_law"]',
                resource_id=f"/subscriptions/{_firewall_subscription_id}/resourceGroups/{_firewall_resource_group_name}/providers/Microsoft.Network/azureFirewalls/{_firewall_name}|diag",
            )

        _dns_subscription_id = _dns_variables["subscription_id"]
        _dns_resource_group_name = _dns_variables["resource_group_name"]

        for _key2, _value2 in _dns_variables["domain_names"].items():
            _logger.info(f"Importing DNS key {_key2} value {_value2}")
            self._import_resource(
                name=f'module.vnet.azurerm_private_dns_zone_virtual_network_link.this["{_key2}"]',
                resource_id=f"/subscriptions/{_dns_subscription_id}/resourceGroups/{_dns_resource_group_name}/providers/Microsoft.Network/privateDnsZones/{_value2}/virtualNetworkLinks/{_vnet_name}",
            )


if __name__ == "__main__":
    _import_state = ImportState()
    _import_state._import()
