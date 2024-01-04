#! /usr/bin/env python
from lib.build import build_sd_image
from lib.deploy import deploy
from lib.create import create
from lib.secrets import secrets
from lib.install import install
from lib.docgen import docgen
import click


@click.group(name="nicos")
@click.option(
    "--ci/--no-ci",
    default=False,
    envvar="CI",
    help="Run in CI mode, which disables prompts. Some commands are not available in CI mode.",
)
@click.option(
    "--docgen/--no-docgen",
    default=False,
    help="Generate help in markdown.",
    hidden=True,
)
@click.pass_context
def main(ctx, ci, docgen):
    ctx.ensure_object(dict)
    ctx.obj["CI"] = ci
    pass


main.add_command(create)
main.add_command(secrets)
main.add_command(build_sd_image)
main.add_command(deploy)
main.add_command(install)
main.add_command(docgen)

if __name__ == "__main__":
    main(obj={})
