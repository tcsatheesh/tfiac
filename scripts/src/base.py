import os
import yaml
import argparse
import logging

from scripts.src.shell import ShellHandler


class ImportStateBase:

    def __init__(
        self,
        *args,
        **kwargs,
    ):
        self.args = kwargs.get(
            "args",
            self.parse_args(),
        )
        _args = self.args

        self._logger = kwargs.get(
            "logger",
            self.get_logger(
                args=_args,
            ),
        )
        _logger = self._logger

        self.shell_handler = kwargs.get(
            "shell_handler",
            ShellHandler(
                args=_args,
                logger=_logger,
            ),
        )

        _logger.info("Importing state...")

        self._services_variables = self._import_variables(
            file_path=_args.services_variables,
        )
        self._vnet_variables = self._import_variables(
            file_path=_args.vnet_variables,
        )
        self._remote_vnet_variables = self._import_variables(
            file_path=_args.remote_vnet_variables,
        )
        self._firewall_variables = self._import_variables(
            file_path=_args.firewall_variables,
        )
        self._log_variables = self._import_variables(
            file_path=_args.log_variables,
        )
        self._dns_variables = self._import_variables(
            file_path=_args.dns_variables,
        )

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
            self._logger.error(f"Variables file not found at {_variables_file_path}")
            raise FileNotFoundError(
                f"Variables file not found at {_variables_file_path}"
            )
        else:
            self._logger.info(f"Importing variables from {_variables_file_path}")
            with open(_variables_file_path, "r") as file:
                _variables = yaml.safe_load(file)
        return _variables

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
        _logger.debug("Import command: %s", _command)
        _output = self.shell_handler.execute_shell_command(
            cwd=self.args.folder,
            command=_command,
        )

    def parse_args(
        self,
    ):
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
            "--services-variables",
            type=str,
            required=True,
            help="Variables to use",
        )
        parser.add_argument(
            "--vnet-variables",
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
            "--log-variables",
            type=str,
            required=True,
            help="Log variables to use",
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
        parser.add_argument(
            "--debug",
            action="store_true",
            help="Enable debug logging",
            default=False,
        )
        _args = parser.parse_args()
        return _args

    def get_logger(
        self,
        args,
    ):
        _args = args
        _log_formatter = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        _log_folder = os.path.abspath(
            os.path.join(
                os.getcwd(),
                "temp",
                "import",
                _args.market,
                _args.environment,
            )
        )
        os.makedirs(
            _log_folder,
            exist_ok=True,
        )
        _log_file_path = os.path.join(
            _log_folder,
            "log.log",
        )
        _file_handler = logging.FileHandler(
            filename=_log_file_path,
            mode="w",
        )
        _file_handler.setFormatter(logging.Formatter(_log_formatter))
        _console_handler = logging.StreamHandler()
        _console_handler.setFormatter(logging.Formatter(_log_formatter))

        _logger = logging.getLogger(__name__)
        _logger.setLevel(logging.DEBUG if _args.debug else logging.INFO)
        _logger.addHandler(_file_handler)
        _logger.addHandler(_console_handler)
        _logger.info("Logger initialized")

        return _logger
