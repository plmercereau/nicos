from box import Box
from lib.command import run_command
import json
import os
import sys


NICOS_FLAKE = os.getenv("NICOS_FLAKE")
OVERRIDE_FLAKE = f"--override-input nicos {NICOS_FLAKE}" if NICOS_FLAKE else ""

"""
TODO update the docstring
gets a subset of the flake outputs from a list of filters, for example:
cluster.secrets
nixosConfigurations.*.config.networking.wireless.enable

if for some reason the target filter doesn't exist, it will return None as soon as a non-existing value is hit in its path
"""


# TODO only list the available machines if no filter is provided
def get_machines_config(*filters):
    print("Loading the cluster configuration...", file=sys.stderr)
    lib_path = os.path.dirname(os.path.abspath(__file__))

    nix_filters = " ".join([f'"{f}"' for f in filters])
    result = run_command(
        f"""nix eval --json --impure --no-write-lock-file --quiet .#nixosConfigurations {OVERRIDE_FLAKE} --apply '(import {lib_path}/lib.nix) [{nix_filters}]'"""
    )
    return Box(json.loads(result))


def get_cluster_config(*filters):
    print("Loading the cluster configuration...", file=sys.stderr)
    lib_path = os.path.dirname(os.path.abspath(__file__))

    nix_filters = " ".join([f'"{f}"' for f in filters])

    result = run_command(
        f"""nix eval --json --impure --no-write-lock-file --quiet .#cluster {OVERRIDE_FLAKE} --apply '(import {lib_path}/lib.nix) [{nix_filters}]'"""
    )
    return Box(json.loads(result))
