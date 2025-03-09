import subprocess


class ShellHandler:
    """
    Shell handler class.
    """

    def __init__(
        self,
        *args,
        **kwargs,
    ):
        self._logger = kwargs.get("logger", None)
        self._args = kwargs.get("args", None)

    def execute_shell_command(
        self,
        cwd,
        command,
        json_output=False,
    ):
        """
        Execute the shell command.
        """
        _args = self._args

        _command = command
        self._logger.info(f"Working directory: {cwd}")
        self._logger.info(f"Executing shell command: {_command}")
        if _args.yes:
            try:
                _output = subprocess.run(
                    _command,
                    check=True,
                    capture_output=True,
                    cwd=cwd,
                )
                self._logger.info(
                    f"Shell command output return code: {_output.returncode}"
                )

                if _output.returncode == 0:
                    if _output.stdout:
                        _stdout = _output.stdout.decode("utf-8")
                        self._logger.info(f"Shell command output: {_stdout}")
                        if json_output:
                            return json.loads(_stdout)
                else:
                    if _output.stderr:
                        _stderr = _output.stderr.decode("utf-8")
                        self._logger.error(f"Shell command error: {_stderr}")
            except subprocess.CalledProcessError as e:
                self._logger.error(f"Shell command error: {e}")
                _stdout = e.stdout.decode("utf-8")
                self._logger.info(f"Shell command output: {_stdout}")
                _stderr = e.stderr.decode("utf-8")
                self._logger.error(f"Shell command error: {_stderr}")

