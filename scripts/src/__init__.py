import os
import json
import yaml
import shutil
import logging
import argparse

from scripts.src.shell import ShellHandler

class Backend:
    """
    Backend class.
    """

    def __init__(
        self,
        *args,
        **kwargs,
    ):
        self._args = kwargs.get(
            "args",
            None,
        )
        self._logger = kwargs.get(
            "logger",
            None,
        )
        self._shell_handler = kwargs.get(
            "shell_handler",
            None,
        )

    def _get_backend_configuration(
        self,
    ):
        _args = self._args
        _folder = os.path.abspath(os.getcwd())
        self._logger.info(f"Folder to backend configuration: {_folder}")
        _backend_configuration_file = os.path.join(
            _folder,
            _args.backend,
        )
        self._logger.info(f"Backend configuration file: {_backend_configuration_file}")
        _backend_configuration_file = os.path.abspath(_backend_configuration_file)
        if os.path.exists(_backend_configuration_file):
            self._logger.info(
                f"Backend configuration file full path: {_backend_configuration_file}"
            )
        else:
            self._logger.error(
                f"Backend configuration file {_backend_configuration_file} not found."
            )

        _backend_configuration = yaml.safe_load(
            open(
                _backend_configuration_file,
                "r",
            )
        )
        self._logger.info(f"Backend configuration: {_backend_configuration}")
        return _backend_configuration.get("backend", None)

    def get_backend_variables(
        self,
    ):
        """
        Get the backend variables.
        """
        _args = self._args

        self._logger.info(f"Variables to use: {_args.variables}")

        _backend_variables = self._get_backend_configuration()

        _key_variables_file = os.path.abspath(_args.variables)
        if os.path.exists(_key_variables_file):
            self._logger.info(f"Variables to use full path: {_key_variables_file}")
        else:
            self._logger.error(f"Variables {_key_variables_file} not found.")

        _variables = yaml.safe_load(open(_key_variables_file, "r"))
        _key_backend_variables = _variables.get("backend", None)
        self._logger.info(f"Key backend variables: {_key_backend_variables}")

        _backend_config = _backend_variables | _key_backend_variables
        self._logger.info(f"Backend configuration: {_backend_config}")
        return _backend_config

    def prepare_backend_config(
        self,
        variables,
    ):
        _command = []
        for _name in [
            "subscription_id",
            "resource_group_name",
            "storage_account_name",
            "container_name",
            "key",
        ]:
            _command.append(f"-backend-config={_name}={variables.get(_name)}")
        return _command

    def _get_backend_storage_command(
        self,
        variables,
        command,
    ):
        _shell_command = []
        _shell_command.append("az")
        _shell_command.append("storage")
        _shell_command.append("blob")
        _shell_command.append(command)
        _shell_command.append("--auth-mode")
        _shell_command.append("login")
        _shell_command.append("--subscription")
        _shell_command.append(variables.get("subscription_id"))
        _shell_command.append("--account-name")
        _shell_command.append(variables.get("storage_account_name"))
        _shell_command.append("--container-name")
        _shell_command.append(variables.get("container_name"))
        _shell_command.append("--name")
        _shell_command.append(variables.get("key"))
        return _shell_command

    def _remove_terraform_files(
        self,
        folder,
    ):
        _folder = folder
        _terraform_paths = [
            ".terraform",
            ".terraform.lock.hcl",
        ]
        for _terraform_path in _terraform_paths:
            _terraform_path = os.path.join(
                _folder,
                ".terraform",
            )
            self._logger.info(f"terraform path: {_terraform_path}")
            if os.path.exists(_terraform_path):
                self._logger.info(f"terraform path to delete: {_terraform_path}")
                if _args.yes:
                    shutil.rmtree(
                        _terraform_path,
                        ignore_errors=True,
                    )
                    self._logger.info(f"Folder {_terraform_path} deleted.")
            else:
                self._logger.info(f"terraform path {_terraform_path} not found.")

    def _remove_state_file(
        self,
        variables,
        folder,
    ):
        _folder = folder
        _variables = variables
        _shell_command = self._get_backend_storage_command(
            variables=_variables,
            command="exists",
        )

        _exists = self._shell_handler.execute_shell_command(
            cwd=_folder,
            command=_shell_command,
            json_output=True,
        )
        if _exists["exists"]:
            _shell_command = self._get_backend_storage_command(
                variables=_variables,
                command="delete",
            )
            self._logger.info(f"Deleting backend storage blob: {_shell_command}")
            if _args.yes:
                self._shell_handler.execute_shell_command(
                    cwd=_folder,
                    command=_shell_command,
                )
                self._logger.info(
                    f"Backend storage blob {_variables.get('key')} deleted."
                )
        else:
            self._logger.info(
                f"Backend storage blob {_variables.get('key')} not found."
            )

    def reset(
        self,
    ):
        """
        Reset the scripts module.
        """
        _args = self._args
        self._logger.info("Resetting backend")
        self._logger.info(f"Folder to reset: {_args.folder}")
        _folder = os.path.abspath(_args.folder)
        if os.path.exists(_folder):
            self._logger.info(f"Folder to reset full path: {_folder}")
        else:
            self._logger.error(f"Folder {_folder} not found.")

        _backend_variables = self.get_backend_variables()

        self._remove_terraform_files(
            folder=_folder,
        )

        self._remove_state_file(
            variables=_backend_variables,
            folder=_folder,
        )

        self._logger.info("Resetting backend done.")


class TerraformWrapper:
    """
    Terraform wrapper class.
    """

    def __init__(
        self,
        *args,
        **kwargs,
    ):
        self.args = kwargs.get("args", None)
        self._logger = kwargs.get("logger", None)
        self._shell_handler = kwargs.get("shell_handler", None)
        self._backend = kwargs.get("backend", None)
        _folder = os.path.abspath(self.args.folder)
        if os.path.exists(_folder):
            self._logger.info(f"Folder to terraform full path: {_folder}")
        else:
            self._logger.error(f"Folder {_folder} not found.")
        self._folder = _folder

    def init(
        self,
        args,
    ):
        """
        Initialize the backend.
        """
        self._logger.info("Initializing backend")
        _folder = self._folder
        self._logger.info(f"Folder to initialize: {_folder}")

        _backend_variables = self._backend.get_backend_variables()
        _shell_command = [
            "terraform",
            "init",
        ]
        _shell_command.extend(
            self._backend.prepare_backend_config(
                variables=_backend_variables,
            ),
        )

        self._shell_handler.execute_shell_command(
            cwd=_folder,
            command=_shell_command,
        )

        self._logger.info("Initializing backend done.")
        pass

    def plan(
        self,
    ):
        """
        Plan the scripts module.
        """
        _folder = self._folder
        _logger.info("Showing plan for backend")
        _logger.info("Folder for plan: %s", _folder)
        _shell_command = [
            "terraform",
            "plan",
        ]
        self._shell_handler.execute_shell_command(
            cwd=_folder,
            command=_shell_command,
        )
        _logger.info("Showing plan done.")

    def apply(
        self,
    ):
        """
        Apply the scripts module.
        """
        _folder = self._folder
        _logger.info("Applying backend")
        _logger.info("Folder for apply: %s", _folder)
        _shell_command = [
            "terraform",
            "apply",
            "-auto-approve",
        ]
        self._shell_handler.execute_shell_command(
            cwd=_folder,
            command=_shell_command,
        )
        _logger.info("Applying backend done.")

    def destroy(
        self,
    ):
        """
        Destroy the scripts module.
        """
        _folder = self._folder
        _logger.info("Destroying backend")
        _logger.info("Folder for destroy: %s", _folder)
        _shell_command = [
            "terraform",
            "destroy",
            "-auto-approve",
        ]
        self._shell_handler.execute_shell_command(
            cwd=_folder,
            command=_shell_command,
        )
        _logger.info("Destroying backend done.")


class Main:
    """
    Main class.
    """

    def __init__(
        self,
        *args,
        **kwargs,
    ):
        self._logger = kwargs.get("logger", None)

    def parse_args(
        self,
    ):
        """
        Parse command line arguments.
        """
        parser = argparse.ArgumentParser(
            description="Scripts module",
        )
        subparsers = parser.add_subparsers(
            dest="command",
        )

        # Initialize command
        init_parser = subparsers.add_parser(
            "init",
            help="Initialize the backend",
        )
        init_parser.add_argument(
            "--folder",
            type=str,
            required=True,
            help="Folder to initialize",
        )
        init_parser.add_argument(
            "--variables",
            type=str,
            required=True,
            help="Variables to use",
        )
        init_parser.add_argument(
            "--backend",
            type=str,
            required=False,
            help="Backend configuration file",
            default="variables/grp/prd/bed.yaml",
        )
        init_parser.add_argument(
            "--yes",
            action="store_true",
            help="Yes to all",
            default=False,
        )

        # Plan command
        plan_parser = subparsers.add_parser(
            "plan",
            help="Plan the scripts module",
        )
        plan_parser.add_argument(
            "--folder",
            type=str,
            required=True,
            help="Folder to initialize",
        )
        plan_parser.add_argument(
            "--variables",
            type=str,
            required=True,
            help="Variables to use",
        )
        plan_parser.add_argument(
            "--yes",
            action="store_true",
            help="Yes to all",
            default=True,
        )

        # Apply command
        apply_parser = subparsers.add_parser(
            "apply",
            help="Apply the scripts module",
        )
        apply_parser.add_argument(
            "--folder",
            type=str,
            required=True,
            help="Folder to initialize",
        )
        apply_parser.add_argument(
            "--variables",
            type=str,
            required=True,
            help="Variables to use",
        )
        apply_parser.add_argument(
            "--yes",
            action="store_true",
            help="Yes to all",
            default=False,
        )

        # Destroy command
        destroy_parser = subparsers.add_parser(
            "destroy",
            help="Destroy the scripts module",
        )
        destroy_parser.add_argument(
            "--folder",
            type=str,
            required=True,
            help="Folder to initialize",
        )
        destroy_parser.add_argument(
            "--variables",
            type=str,
            required=True,
            help="Variables to use",
        )
        destroy_parser.add_argument(
            "--yes",
            action="store_true",
            help="Yes to all",
            default=False,
        )

        # Reset command
        reset_parser = subparsers.add_parser(
            "reset",
            help="Reset the scripts module",
        )
        reset_parser.add_argument(
            "--folder",
            type=str,
            required=True,
            help="Folder to reset",
        )
        reset_parser.add_argument(
            "--variables",
            type=str,
            required=True,
            help="Variables to use",
        )
        reset_parser.add_argument(
            "--backend",
            type=str,
            required=False,
            help="Backend configuration file",
            default="variables/grp/prd/bed.yaml",
        )
        reset_parser.add_argument(
            "--force",
            action="store_true",
            help="Force reset",
            default=False,
        )
        reset_parser.add_argument(
            "--yes",
            action="store_true",
            help="Yes to all",
            default=False,
        )

        return parser.parse_args()


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
    _logger = logging.getLogger(__name__)

    _main = Main(
        logger=_logger,
    )
    _args = _main.parse_args()

    _shell_handler = ShellHandler(
        logger=_logger,
        args=_args,
    )

    _backend = Backend(
        args=_args,
        logger=_logger,
        shell_handler=_shell_handler,
    )

    _terraform_wrapper = TerraformWrapper(
        args=_args,
        logger=_logger,
        backend=_backend,
        shell_handler=_shell_handler,
    )

    if _args.command == "init":
        _terraform_wrapper.init(args=_args)
    elif _args.command == "plan":
        _terraform_wrapper.plan()
    elif _args.command == "apply":
        _terraform_wrapper.apply()
    elif _args.command == "destroy":
        _terraform_wrapper.destroy()
    elif _args.command == "reset":
        _backend.reset()
