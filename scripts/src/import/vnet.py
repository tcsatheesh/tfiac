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
        _variables_file_path = os.path.join(
            os.path.abspath(os.getcwd()),
            _args.variables,
        )
        _variables_file_path = os.path.abspath(
            _variables_file_path,
        )

        if not os.path.exists(_variables_file_path):
            self._logger.error(f"Variables file not found at {_variables_file_path}")
        else:
            self._logger.info(f"Importing variables from {_variables_file_path}")
            with open(_variables_file_path, "r") as file:
                _variables = yaml.safe_load(file)

            _subscription_id = _variables["subscription_id"]
            _resource_group_name = _variables["resource_group_name"]

            for _key, _value in _variables["subnets"].items():
                _logger.info(f"{_key}: {_value}")
                _nsg_name = _value["nsg"]
                self._import_resource(
                    name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_group.this',
                    resource_id=f'/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/networkSecurityGroups/{_nsg_name}',
                )
                self._import_resource(
                    name=f'module.vnet.module.subnets["{_key}"].azapi_resource.subnet',
                    resource_id=f'/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_variables["name"]}/subnets/{_key}',
                )
                for _key1, _value1 in _value["nsg_rules"].items():
                    _logger.info(f"{_key1}: {_value1}")
                    self._import_resource(
                        name=f'module.vnet.module.nsg["{_key}"].azurerm_network_security_rule.this["{_key1}"]',
                        resource_id=f'/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/networkSecurityGroups/{_nsg_name}/securityRules/{_value1["name"]}',
                    )
            self._import_resource(
                name="module.vnet.azurerm_route_table.this",
                resource_id=f'/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/routeTables/{_variables["route_table_name"]}',
            )
            self._import_resource(
                name="module.vnet.azurerm_resource_group.this",
                resource_id=f'/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}',
            )
            self._import_resource(
                name="module.vnet.module.vnet.azapi_resource.vnet",
                resource_id=f'/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_variables["name"]}',
            )
            self._import_resource(
                name='module.vnet.module.vnet.azurerm_monitor_diagnostic_setting.this["sendToLogAnalytics"]',
                resource_id=f'/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/virtualNetworks/{_variables["name"]}|sendToLogAnalytics',
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
