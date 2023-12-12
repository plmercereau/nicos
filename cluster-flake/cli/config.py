import json
import subprocess
import sys

def get_cluster_config(selection = []):
    nixSelection = "".join([f"{item} = v.{item}; " for item in selection]  )
    command = f"nix eval .#cluster --json --quiet --no-write-lock-file --apply 'let pick = v: {{{nixSelection}}}; in pick'"
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        # Handle the error
        error_message = result.stderr
        print(f"Error evaluating the cluster secrets: {error_message}")
        sys.exit(1)
    return json.loads(result.stdout)
