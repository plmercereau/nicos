from lib.config import get_cluster_config
import click
import glob
import inquirer
import os


@click.command(help="Deploy one or several existing machines")
@click.pass_context
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
def deploy(ctx, machines, all, nixos, darwin):
    ci = ctx.obj["CI"]
    cfg = get_cluster_config(
        "configs.*.config.nixpkgs.hostPlatform.isDarwin",
    )["configs"]
    darwinHosts = [
        x
        for x in cfg
        if cfg[x]["config"]["nixpkgs"]["hostPlatform"]["isDarwin"] == True
    ]
    nixosHosts = [
        x
        for x in cfg
        if cfg[x]["config"]["nixpkgs"]["hostPlatform"]["isDarwin"] == False
    ]
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
    elif not ci:
        questions = [
            inquirer.Checkbox(
                "hosts", message="Which machine do you want to deploy?", choices=choices
            ),
        ]
        machines = inquirer.prompt(questions)["hosts"]

    if not machines:
        print("No machine selected for deployment.")
        exit(1)

    print("Deploying %s..." % (", ".join(machines)))
    targets = [f".#{machine}" for machine in machines]
    # TODO fails
    os.system("nix run github:serokell/deploy-rs -- --targets %s" % (" ".join(targets)))
