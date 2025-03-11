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

    def _import_log(
        self,
    ):
        _args = self.args
        _logger = self._logger
        _logger.info("Importing Log Analytics state...")
        _log_variables_file_path = os.path.join(
            os.path.abspath(os.getcwd()),
            _args.variables,
        )
        _log_variables_file_path = os.path.abspath(
            _log_variables_file_path,
        )

        if not os.path.exists(_log_variables_file_path):
            self._logger.error(
                f"Log Analytics variables file not found at {_log_variables_file_path}"
            )
        else:
            self._logger.info(
                f"Importing Log Analytics variables from {_log_variables_file_path}"
            )
            with open(_log_variables_file_path, "r") as file:
                _log_variables = yaml.safe_load(file)

            _subscription_id = _log_variables["subscription_id"]
            _resource_group_name = _log_variables["resource_group_name"]
            _workspace_name = _log_variables["workspace_name"]

            _command = [
                "terraform",
                "import",
                "-var",
                f"market={_args.market}",
                "-var",
                f"environment={_args.environment}",
                "-var",
                f"env_type={_args.env_type}",
                f'module.log.module.log_analytics_workspace.azurerm_log_analytics_workspace.this',
                f"/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/{_workspace_name}",
            ]
            _logger.info("Import command: %s", _command)
            _output = self.shell_handler.execute_shell_command(
                cwd=self.args.folder,
                command=_command,
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Import Log Analytics state",
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
        "--env_type",
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
    _import_state._import_log()
