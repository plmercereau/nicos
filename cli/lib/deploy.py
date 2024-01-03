from lib.config import get_cluster_config
import click
import questionary
import os


# TODO handle deployment of the current machine
@click.command(help="Deploy one or several existing machines")
@click.pass_context
@click.argument("machines", nargs=-1)
@click.option(
    "--network",
    default="default",
    type=click.Choice(["vpn", "lan", "public", "default"], case_sensitive=False),
    help="Way to connect to the machines.",
)
@click.option(
    "--all", is_flag=True, default=False, help="Deploy all available machines."
)
@click.option(
    "--nixos",
    is_flag=True,
    default=False,
    help="Include the NixOS machines.",
)
@click.option(
    "--darwin",
    is_flag=True,
    default=False,
    help="Include the Darwin machines.",
)
@click.option(
    "--remote-build",
    is_flag=True,
    default=False,
    help="Build on remote host.",
)
# TODO deploy-rs -s/--skip-checks option
# TODO add an option to deploy the bastions (and to put them at the beginning/end of the list?)
# TODO add an option to include the current host (and to put it at the very end of the list)
def deploy(ctx, machines, all, nixos, darwin, network, remote_build):
    ci = ctx.obj["CI"]
    cfg = get_cluster_config(
        "configs.*.config.nixpkgs.hostPlatform.isLinux",
        "configs.*.config.nixpkgs.hostPlatform.isDarwin",
    ).configs
    choices = []
    if all:
        nixos = True
        darwin = True
    if nixos or (not nixos and not darwin):
        choices += [k for k, v in cfg.items() if v.config.nixpkgs.hostPlatform.isLinux]
    if darwin or (not nixos and not darwin):
        choices += [k for k, v in cfg.items() if v.config.nixpkgs.hostPlatform.isDarwin]
    choices = sorted(choices)

    if nixos or darwin:
        machines = choices

    if machines:
        # Check if the machines exists
        unknown_machines = [m for m in machines if m not in choices]
        if unknown_machines:
            print("Unknown machines: %s" % ", ".join(unknown_machines))
            exit(1)
    elif not ci:
        if not choices:
            print("No machine available for deployment.")
            exit(1)
        machines = questionary.checkbox(
            "Which machines do you want to deploy?", choices=choices
        ).ask()

    if not machines:
        print("No machine selected for deployment.")
        exit(1)

    profile = "system" if network == "default" else network
    print("Deploying %s..." % (", ".join(machines)))
    opts = ["--targets"] + [f".#{machine}.{profile}" for machine in machines]
    if remote_build:
        opts.append("--remote-build")
    os.system("nix run github:serokell/deploy-rs -- %s" % (" ".join(opts)))
