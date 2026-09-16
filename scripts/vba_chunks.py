#!/usr/bin/env python3
"""Print VBA string assignments for a PowerShell -EncodedCommand value."""

import argparse
import base64
import binascii
import sys


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Split a UTF-16LE Base64 PowerShell command into VBA string assignments."
    )
    parser.add_argument(
        "encoded",
        nargs="?",
        help="Base64 value; omit to paste it or pipe it on stdin",
    )
    args = parser.parse_args()

    if args.encoded is not None:
        supplied = args.encoded
    elif sys.stdin.isatty():
        supplied = input("Paste UTF-16LE Base64 command: ")
    else:
        supplied = sys.stdin.read()

    encoded = "".join(supplied.split())
    if not encoded:
        parser.error("no Base64 value supplied")

    try:
        base64.b64decode(encoded, validate=True).decode("utf-16-le")
    except (binascii.Error, UnicodeDecodeError) as exc:
        parser.error(f"expected a UTF-16LE Base64 command: {exc}")

    command = "powershell.exe -NoProfile -EncodedCommand " + encoded
    for offset in range(0, len(command), 50):
        print(f'    cmd = cmd & "{command[offset:offset + 50]}"')


if __name__ == "__main__":
    main()
