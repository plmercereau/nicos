from lib.config import get_cluster_config
import glob
import inquirer
import os


def deploy(machines=[], all=False):
    """Deploy one or several machines"""
    if isinstance(machines, str):
        machines = [
            machines
        ]  # ! In python fire, when there is only one argument, it is a string
    cfg = get_cluster_config(["hosts.nixosPath", "hosts.darwinPath"])["hosts"]

    def host_names(hostsPath):
        if hostsPath is None:
            return []
        return [
            os.path.splitext(os.path.basename(file))[0]
            for file in glob.glob(f"{hostsPath}/*.nix")
        ]

    darwinHosts = host_names(cfg["darwinPath"])
    nixosHosts = host_names(cfg["nixosPath"])
    choices = sorted(nixosHosts + darwinHosts)

    if all:
        machines = choices

    if not machines:
        questions = [
            inquirer.Checkbox(
                "hosts", message="Which host do you want to deploy?", choices=choices
            ),
        ]
        machines = inquirer.prompt(questions)["hosts"]

    if not machines:
        print("No machine to deploy")
        return

    print("Deploying %s..." % (", ".join(machines)))
    targets = [f".#{machine}" for machine in machines]
    # TODO fails
    os.system("nix run github:serokell/deploy-rs -- --targets %s" % (" ".join(targets)))
