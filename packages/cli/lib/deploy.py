from lib.config import get_machines_config, OVERRIDE_FLAKE
import click
import questionary
import os


# TODO handle deployment of the current machine
@click.command(
    help="Deploy one or several existing machines",
    context_settings=dict(
        ignore_unknown_options=True,  # Allow unknown options
    ),
)
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
    "--remote-build",
    is_flag=True,
    default=False,
    help="Build on remote host.",
)
# TODO deploy-rs -s/--skip-checks option
# TODO add an option to deploy the bastions (and to put them at the beginning/end of the list?)
# TODO add an option to include the current host (and to put it at the very end of the list)
def deploy(machines, all, network, remote_build):
    cfg = get_machines_config("*.config.networking.hostName")
    choices = sorted([k for k, v in cfg.items()])

    if all:
        machines = choices

    if machines:
        # Check if the machines exists
        unknown_machines = [m for m in machines if m not in choices]
        if unknown_machines:
            print("Unknown machines: %s" % ", ".join(unknown_machines))
            exit(1)
    else:
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
    os.system(
        "nix run github:serokell/deploy-rs -- %s -- %s"
        % (" ".join(opts), OVERRIDE_FLAKE),
    )
