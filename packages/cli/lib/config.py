from box import Box
from lib.command import run_command
import json
import os
import sys

"""
gets a subset of the flake outputs from a list of filters, for example:
cluster.secrets
nixosConfigurations.*.config.networking.wireless.enable

if for some reason the target filter doesn't exist, it will return None as soon as a non-existing value is hit in its path
"""


def get_cluster_config(*filters):
    print("Loading the cluster configuration...", file=sys.stderr)
    lib_path = os.path.dirname(os.path.abspath(__file__))

    flake_url = json.loads(
        run_command("nix flake metadata --json --no-write-lock-file --quiet")
    )["url"]
    nix_filters = " ".join([f'"{f}"' for f in filters])

    return Box(
        json.loads(
            run_command(
                f"""nix eval --json --impure --no-write-lock-file --quiet --expr '(import {lib_path}/lib.nix).pickInFlake "{flake_url}" [{nix_filters}]'"""
            )
        )
    )
