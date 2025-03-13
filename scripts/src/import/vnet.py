import os
import yaml
import argparse
import logging

from scripts.src.shell import ShellHandler


class ImportState:

    def __init__(
        self,
        *args,
        **kwargs,
    ):
        self.args = kwargs.get("args", None)
        self._logger = kwargs.get("logger", None)
        self.shell_handler = kwargs.get("shell_handler", None)

    def _import_resource(
        self,
        name,
        resource_id,
    ):
        _args = self.args
        _logger = self._logger
        _command = [
            "terraform",
            "import",
            "-var",
            f"market={_args.market}",
            "-var",
            f"environment={_args.environment}",
            "-var",
            f"env_type={_args.env_type}",
            name,
            resource_id,
        ]
        _logger.info("Import command: %s", _command)
        _output = self.shell_handler.execute_shell_command(
            cwd=self.args.folder,
            command=_command,
        )

    def _import_vnet(
        self,
    ):
        _args = self.args
        _logger = self._logger
        _logger.info("Importing state...")
        _vnet_variables_file_path = os.path.join(
            os.path.abspath(os.getcwd()),
            _args.variables,
        )
        _vnet_variables_file_path = os.path.abspath(
            _vnet_variables_file_path,
        )

        if not os.path.exists(_vnet_variables_file_path):
            self._logger.error(f"Variables file not found at {_vnet_variables_file_path}")
        else:
            self._logger.info(f"Importing variables from {_vnet_variables_file_path}")
            with open(_vnet_variables_file_path, "r") as file:
                _vnet_variables = yaml.safe_load(file)

            _vnet_subscription_id = _vnet_variables["subscription_id"]
            _vnet_resource_group_name = _vnet_variables["resource_group_name"]

            for _key, _value in _vnet_variables["subnets"].items():
                _logger.info(f"{_key}: {_value}")
                _nsg_name = _value["nsg"]
                self._import_resource(
                    name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_group.this',
                    resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/networkSecurityGroups/{_nsg_name}',
                )
                self._import_resource(
                    name=f'module.vnet.module.subnets["{_key}"].azapi_resource.subnet',
                    resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_variables["name"]}/subnets/{_key}',
                )
                for _key1, _value1 in _value["nsg_rules"].items():
                    _logger.info(f"{_key1}: {_value1}")
                    self._import_resource(
                        name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_rule.this["{_key1}"]',
                        resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/networkSecurityGroups/{_nsg_name}/securityRules/{_value1["name"]}',
                    )
            self._import_resource(
                name="module.vnet.azurerm_route_table.this",
                resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/routeTables/{_vnet_variables["route_table_name"]}',
            )
            self._import_resource(
                name="module.vnet.azurerm_resource_group.this",
                resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}',
            )
            self._import_resource(
                name="module.vnet.module.vnet.azapi_resource.vnet",
                resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_variables["name"]}',
            )
            self._import_resource(
                name='module.vnet.module.vnet.azurerm_monitor_diagnostic_setting.this["sendToLogAnalytics"]',
                resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_variables["name"]}|sendToLogAnalytics',
            )

            _remote_vnet_variables_file_path = os.path.join(
                os.path.abspath(os.getcwd()),
                _args.remote_vnet_variables,
            )
            _remote_vnet_variables_file_path = os.path.abspath(
                _remote_vnet_variables_file_path,
            )

            if not os.path.exists(_remote_vnet_variables_file_path):
                self._logger.error(f"Remote VNet variables file not found at {_remote_vnet_variables_file_path}")
            else:
                self._logger.info(f"Importing Remote VNet variables from {_remote_vnet_variables_file_path}")
                with open(_remote_vnet_variables_file_path, "r") as file:
                    _remote_vnet_variables = yaml.safe_load(file)

                _remote_vnet_subscription_id = _remote_vnet_variables["subscription_id"]
                _remote_vnet_resource_group_name = _remote_vnet_variables["resource_group_name"]

                self._import_resource(
                    name='module.vnet.module.peering["enabled"].azapi_resource.this[0]',
                    resource_id=f'/subscriptions/{_vnet_subscription_id}/resourceGroups/{_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_vnet_variables["name"]}/virtualNetworkPeerings/{_vnet_variables["vnet_peering"]["local_name"]}',
                )
                self._import_resource(
                    name='module.vnet.module.peering["enabled"].azapi_resource.reverse[0]',
                    resource_id=f'/subscriptions/{_remote_vnet_subscription_id}/resourceGroups/{_remote_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_remote_vnet_variables["name"]}/virtualNetworkPeerings/{_vnet_variables["vnet_peering"]["remote_name"]}',
                )



            _dns_variables_file_path = os.path.join(
                os.path.abspath(os.getcwd()),
                _args.dns_variables,
            )
            _dns_variables_file_path = os.path.abspath(
                _dns_variables_file_path,
            )

            if not os.path.exists(_dns_variables_file_path):
                self._logger.error(f"DNS variables file not found at {_dns_variables_file_path}")
            else:
                self._logger.info(f"Importing DNS variables from {_dns_variables_file_path}")
                with open(_dns_variables_file_path, "r") as file:
                    _dns_variables = yaml.safe_load(file)

                _dns_subscription_id = _dns_variables["subscription_id"]
                _dns_resource_group_name = _dns_variables["resource_group_name"]

                for _key2, _value2 in _dns_variables["domain_names"].items():
                    _logger.info(f"{_key2}: {_value2}")
                    self._import_resource(
                        name=f'module.vnet.azurerm_private_dns_zone_virtual_network_link.this["{_key2}"]',
                        resource_id=f'/subscriptions/{_dns_subscription_id}/resourceGroups/{_dns_resource_group_name}/providers/Microsoft.Network/privateDnsZones/{_value2}/virtualNetworkLinks/{_vnet_variables["name"]}',
                    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Import state",
    )

    parser.add_argument(
        "--folder",
        type=str,
        required=True,
        help="Folder to initialize",
    )
    parser.add_argument(
        "--variables",
        type=str,
        required=True,
        help="Variables to use",
    )
    parser.add_argument(
        "--dns-variables",
        type=str,
        required=True,
        help="DNS variables to use",
    )
    parser.add_argument(
        "--remote-vnet-variables",
        type=str,
        required=True,
        help="Remote VNet variables to use",
    )
    parser.add_argument(
        "--market",
        type=str,
        required=True,
        help="Market to use",
    )
    parser.add_argument(
        "--environment",
        type=str,
        required=True,
        help="Environment to use",
    )
    parser.add_argument(
        "--env-type",
        type=str,
        required=True,
        help="Environment type to use",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip confirmation prompts",
        default=False,
    )
    _args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
    _logger = logging.getLogger(__name__)

    _shell_handler = ShellHandler(
        args=_args,
        logger=_logger,
    )

    _import_state = ImportState(
        args=_args,
        logger=_logger,
        shell_handler=_shell_handler,
    )
    _import_state._import_vnet()
