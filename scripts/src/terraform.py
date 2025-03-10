import os

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
        _logger = self._logger
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
        _logger = self._logger
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
        _logger = self._logger
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

