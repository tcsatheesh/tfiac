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

    def _import_variables(
        self,
        file_path,
    ):
        _variables_file_path = os.path.join(
            os.path.abspath(os.getcwd()),
            file_path,
        )
        _variables_file_path = os.path.abspath(
            _variables_file_path,
        )
        if not os.path.exists(_variables_file_path):
            self._logger.error(
                f"Variables file not found at {_variables_file_path}"
            )
            raise FileNotFoundError(
                f"Variables file not found at {_variables_file_path}"
            )
        else:
            self._logger.info(
                f"Importing variables from {_variables_file_path}"
            )
            with open(_variables_file_path, "r") as file:
                _variables = yaml.safe_load(file)
        return _variables

    def _import_dns(
        self,
    ):
        _args = self.args
        _logger = self._logger
        _logger.info("Importing DNS state...")

        _dns_variables = self._import_variables(
            file_path=_args.dns_variables,
        )
        _cwd = os.path.join(os.getcwd(), _args.folder)
        _cwd = os.path.abspath(_cwd)

        _subscription_id = _dns_variables["subscription_id"]
        _resource_group_name = _dns_variables["resource_group_name"]

        for _key, _value in _dns_variables["domain_names"].items():
            _logger.info(f"Importing DNS variable {_key} with value {_value}")
            _command = [
                "terraform",
                "import",
                "-var",
                f"market={_args.market}",
                "-var",
                f"environment={_args.environment}",
                "-var",
                f"env_type={_args.env_type}",
                f'module.dns.module.private_dns_zones["{_key}"].azurerm_private_dns_zone.this',
                f"/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/privateDnsZones/{_value}",
            ]
            _logger.info("Import command: %s", _command)
            _output = self.shell_handler.execute_shell_command(
                cwd=_cwd,
                command=_command,
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Import DNS state",
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
        "--firewall-variables",
        type=str,
        required=True,
        help="Firewall variables to use",
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
    _import_state._import_dns()
