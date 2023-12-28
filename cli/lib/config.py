from box import Box
from lib.command import run_command
import json
import os


def get_cluster_config(*filters):
    # ! this would simplify things:
    print("Loading the cluster configuration...")
    lib_path = os.path.dirname(os.path.abspath(__file__))

    print(lib_path)
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
