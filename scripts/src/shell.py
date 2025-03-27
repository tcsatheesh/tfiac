import os
import json
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

        self._log_success_file_path = self._setup_log_file(type="success")
        self._log_failed_file_path = self._setup_log_file(type="failed")

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
        self._logger.debug(f"Working directory: {cwd}")
        self._logger.debug(f"Executing shell command: {_command}")
        if _args.yes:
            try:
                _output = subprocess.run(
                    _command,
                    check=True,
                    capture_output=True,
                    cwd=cwd,
                )
                self._logger.debug(
                    f"Shell command output return code: {_output.returncode}"
                )

                if _output.returncode == 0:
                    self._log_command(
                        log_file_path=self._log_success_file_path,
                        command=_command,
                    )
                    if _output.stdout:
                        _stdout = _output.stdout.decode("utf-8")
                        self._logger.debug(f"Shell command output: {_stdout}")
                        if json_output:
                            return json.loads(_stdout)
                else:
                    if _output.stderr:
                        self._log_command(
                            log_file_path=self._log_failed_file_path,
                            command=_command,
                        )
                        _stderr = _output.stderr.decode("utf-8")
                        self._logger.error(f"Shell command error: {_stderr}")
            except subprocess.CalledProcessError as e:
                self._log_command(
                    log_file_path=self._log_failed_file_path,
                    command=_command,
                )
                self._logger.error(f"CalledProcessError: error : {e}")
                _stdout = e.stdout.decode("utf-8")
                self._logger.info(f"CalledProcessError: _stdout: {_stdout}")
                _stderr = e.stderr.decode("utf-8")
                self._logger.error(f"CalledProcessError: _stderr: {_stderr}")

    def _setup_log_file(
        self,
        type,
    ):
        _args = self._args
        _log_file_folder = os.path.join(
            os.path.abspath(os.getcwd()),
            "temp",
            "import",
            _args.market,
            _args.environment,
            _args.service,
        )
        os.makedirs(
            _log_file_folder,
            exist_ok=True,
        )
        _log_file_path = os.path.join(
            _log_file_folder,
            f"{type}.sh",
        )
        if os.path.exists(_log_file_path):
            os.remove(_log_file_path)

        return _log_file_path

    def _log_command(
        self,
        log_file_path,
        command,
    ):
        # get the first 8 elements of the command
        _command_1 = command[:8]
        # get the 9th element of the command
        _command_2 = command[8]
        # get the last element of the command
        _command_3 = command[-1]

        _log_file_path = log_file_path
        with open(
            _log_file_path,
            "a",
        ) as file:
            file.write(" ".join(_command_1) + " \\\n")
            file.write(_command_2 + " \\\n")
            file.write(_command_3 + " \n")
