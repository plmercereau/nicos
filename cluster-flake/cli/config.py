import json
from run import run_command

def get_cluster_config(selection = []):
    print("Loading the cluster configuration...")
    nixSelection = "".join([f"{item} = v.{item}; " for item in selection]  )
    command = f"nix eval .#cluster --json --quiet --no-write-lock-file --apply 'let pick = v: {{{nixSelection}}}; in pick'"
    return json.loads(run_command(command))
