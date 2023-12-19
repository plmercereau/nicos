from lib.config import get_cluster_config
import click
import glob
import inquirer
import os


@click.command(help="Deploy one or several existing machines")
@click.argument("machines", nargs=-1)
@click.option(
    "--all", is_flag=True, default=False, help="Deploy all available machines."
)
@click.option(
    "--nixos/--no-nixos", is_flag=True, default=True, help="Include the NixOS machines."
)
@click.option(
    "--darwin/--no-darwin",
    is_flag=True,
    default=True,
    help="Include the Darwin machines.",
)
def deploy(machines, all, nixos, darwin):
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
    choices = []
    if nixos:
        choices += nixosHosts
    if darwin:
        choices += darwinHosts
    choices = sorted(choices)

    if all:
        machines = choices

    if machines:
        # Check if the machines exists
        unknown_machines = [m for m in machines if m not in choices]
        if unknown_machines:
            print("Unknown machines: %s" % ", ".join(unknown_machines))
            exit(1)
    else:
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
