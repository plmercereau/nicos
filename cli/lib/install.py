from lib.ip import validateIp
from lib.config import get_cluster_config
from tempfile import TemporaryDirectory
import click
import questionary
import os
import pathlib
import shutil


@click.command(help="Install a machine using nixos-anywhere.")
@click.pass_context
@click.argument("machine", default="")
@click.argument("ip", default="")
@click.option(
    "--user",
    default="root",
    help="User that will connect to the machine through nixos-anywhere.",
)
@click.option(
    "--remote-build",
    is_flag=True,
    default=False,
    help="build the closure on the remote machine instead of locally and copy-closuring it.",
)
def install(ctx, machine, ip, user, remote_build):
    ci = ctx.obj["CI"]
    cfg = get_cluster_config(
        "configs.*.config.nixpkgs.hostPlatform.isLinux",
        "configs.*.config.settings.networking.localIP",
        "configs.*.config.settings.networking.publicIP",
    ).configs

    hosts = [k for k, v in cfg.items() if v.config.nixpkgs.hostPlatform.isLinux]

    hosts = sorted(hosts)

    if machine:
        if not machine in hosts:
            print("Unknown machine, or machine not available for installation.")
            exit(1)
    elif not ci:
        machine = questionary.select(
            "Which machine do you want to install?",
            choices=hosts,
        ).ask()

    if not machine:
        print("No machine selected.")
        exit(1)

    machine_settings = cfg[machine].config.settings
    ip = (
        ip
        or machine_settings.networking.publicIP
        or machine_settings.networking.localIP
    )

    if not ip and not ci:
        ip = questionary.text(
            "What is the IP of the target?",
            validate=lambda x: validateIp(x),
        ).ask()

    if not ip:
        print(
            "No IP provided either from the command line or in the machine configuration."
        )
        exit(1)

    print(f"Installing {machine}...")
    with TemporaryDirectory() as temp_dir:
        try:
            ssh_path = f"{temp_dir}/etc/ssh"
            pathlib.Path(ssh_path).mkdir(parents=True, exist_ok=True, mode=0o755)
            # TODO prompt if the key is not found. Fail if CI mode
            ssh_key_source = f"ssh_{machine}_ed25519_key"
            ssh_key_target = f"{ssh_path}/ssh_host_ed25519_key"
            shutil.copy2(ssh_key_source, ssh_key_target)
            os.chmod(ssh_key_target, 0o600)
            opts = [
                "--extra-files",
                temp_dir,
                " --ssh-option",
                "'GlobalKnownHostsFile=/dev/null'",
                "--flake",
                f"'.#{machine}'",
            ]
            if remote_build:
                opts += ["--build-on-remote"]
            os.system("nixos-anywhere %s %s@%s" % (" ".join(opts), user, ip))
        finally:
            # TemporaryDirectory(delete=True) does not work for some reason
            shutil.rmtree(temp_dir)
