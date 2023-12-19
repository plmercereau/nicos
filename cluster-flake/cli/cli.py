#! /usr/bin/env python
from lib.build import build_sd_image
from lib.deploy import deploy
from lib.create import create
from lib.secrets import secrets

import click


@click.group()
@click.option(
    "--ci/--no-cli",
    default=False,
    envvar="CI",
    help="Run in CI mode, which disables prompts",
)
@click.pass_context
def cli(ctx, ci):
    ctx.ensure_object(dict)
    ctx.obj["CI"] = ci
    pass


cli.add_command(create)
cli.add_command(secrets)
cli.add_command(build_sd_image)
cli.add_command(deploy)
# TODO build a live CD image
# TODO install a machine from the live CD image:
# * 1. boot from the live CD image
# * 2. run the deploy command + copy the ssh private key using nixos-anywhere

if __name__ == "__main__":
    cli(obj={})
