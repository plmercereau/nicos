import json
from lib.command import run_command

# TODO get rid of cluster.hosts.settings now that we pick fields from hosts.config?
def get_cluster_config(selection):
    print("Loading the cluster configuration...")
    other = [x for x in selection if not x.startswith("hosts.config.")]
    nixSelection = "".join([f"{item} = c.{item}; " for item in other])

    # Pick specific fields from hosts.config
    hostConf = [x for x in selection if x.startswith("hosts.config.")]
    hostConf = [x.replace("hosts.config.", "") for x in hostConf]
    if (hostConf):
        nixSelection += "hosts.config = lib.mapAttrs (_: i: {" + "".join([f"""{item} = lib.attrByPath ["{'" "'.join(item.split('.'))}"] null i; """ for item in hostConf ]) + "}) c.hosts.config; "

    command = f"nix eval .#cluster --impure --json --quiet --no-write-lock-file --apply 'let pkgs = import <nixpkgs> {{}}; inherit (pkgs) lib; pick = c: {{{nixSelection}}}; in pick'"
    return json.loads(run_command(command))
