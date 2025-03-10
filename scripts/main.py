
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
            default="../../variables/grp/prd/bed.yaml",
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

        # Apply command
        apply_parser = subparsers.add_parser(
            "apply",
            help="Apply the scripts module",
        )

        # Destroy command
        destroy_parser = subparsers.add_parser(
            "destroy",
            help="Destroy the scripts module",
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
            default="../../variables/grp/prd/bed.yaml",
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
    elif _args.command == "reset":
        _backend.reset()
