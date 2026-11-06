"""Allows `python -m shell_cook`."""

# pylint: disable=invalid-name

import sys

from shell_cook import cli

if __name__ == "__main__":
    sys.exit(cli.main())
