from cryptography.hazmat.primitives import serialization
from lib.command import run_command
from lib.config import get_cluster_config
from lib.ssh import public_key_to_string
from psutil import disk_partitions
from tempfile import TemporaryDirectory
import click
import inquirer
import platform
import re
import shutil
import subprocess


@click.command(name="build", help="Build a machine ISO image.")
@click.pass_context
@click.argument("machine", default="")
@click.argument("device", default="")
@click.option(
    "--private-key-path",
    "-k",
    help="The path to the private key to use. Defaults to ssh_<machine>_ed25519_key.",
)
# TODO add options
def build_sd_image(ctx, machine, private_key_path, device):
    ci = ctx.obj["CI"]
    sys_partitions = disk_partitions()  # "System" partitions
    all_partitions = disk_partitions(
        all=True
    )  # "System" partitions + usb / sd card / etc.
    partitions = [
        x for x in all_partitions if x not in sys_partitions and "/" in x.device
    ]

    if not partitions:
        print("No SD card found. Please insert one and try again.")
        exit(1)

    hostsConf = get_cluster_config(
        "nixosConfigurations.*.config.sdImage.imageName",
        "nixosConfigurations.*.config.settings.sshPublicKey",
    )["nixosConfigurations"]

    sd_machine_choices = [
        x for x in hostsConf if hostsConf[x]["config"]["sdImage"]["imageName"]
    ]

    if machine:
        if machine not in sd_machine_choices:
            print(
                "The machine %s does not have a SD image configuration. Please select one of the following machines: %s"
                % (machine, ", ".join(sd_machine_choices))
            )
            exit(1)
    else:
        if ci:
            print(
                "No machine specified. Please select one of the following machines: %s"
                % ({", ".join(sd_machine_choices)})
            )
            exit(1)
        machine = inquirer.prompt(
            [
                inquirer.List(
                    "machine",
                    message="Select the machine for the SD image to build",
                    choices=sd_machine_choices,
                )
            ]
        )["machine"]

    if not private_key_path:
        private_key_path = f"ssh_{machine}_ed25519_key"

    def validate_key_path(_, current):
        try:
            with open(current, "rb") as private_key_file:
                private_key = serialization.load_ssh_private_key(
                    private_key_file.read(), password=None
                )
        except Exception:
            raise inquirer.errors.ValidationError(
                "", reason=f"The file {current} is an invalid private key file."
            )

        ssh_public_key = hostsConf[machine]["config"]["settings"]["sshPublicKey"]
        if ssh_public_key == public_key_to_string(private_key.public_key()):
            return True
        raise inquirer.errors.ValidationError(
            "", reason=f"The private key in {current} does not match the public key."
        )

    try:
        validate_key_path({}, private_key_path)
    except inquirer.errors.ValidationError as e:
        print(e.reason)
        if ci:
            exit(1)
        private_key_path = inquirer.prompt(
            [
                inquirer.Path(
                    "private_key_path",
                    message="Select the private key to use",
                    validate=validate_key_path,
                    exists=True,
                    path_type=inquirer.Path.FILE,
                )
            ]
        )["private_key_path"]

    device_choices = []
    for x in partitions:
        device = re.match(r"(/dev/disk\d+)", x.device.replace("msdos:/", "/dev")).group(
            1
        )
        device_choices.append((f"{device} ({x.device} on {x.mountpoint})", device))

    if not device:
        if ci:
            print("No device specified. Please select one of the following devices: %s")
            exit(1)
        device = inquirer.prompt(
            [
                inquirer.List(
                    "device",
                    message="Select the device where the SD image will be written",
                    choices=device_choices,
                )
            ]
        )["device"]

    with TemporaryDirectory() as temp_dir:
        try:
            print("Building the SD image...")
            image_name = hostsConf[machine]["config"]["sdImage"]["imageName"]
            result = run_command(
                f"nix build .#nixosConfigurations.{machine}.config.system.build.sdImage --no-link --print-out-paths"
            )
            image_file = f"{result}/sd-image/{image_name}"

            # TODO check if paragon extfs is installed when on darwin
            mount_cmd = (
                "/usr/local/sbin/mount_ufsd_ExtFS"
                if platform.system() == "Darwin"
                else "mount"
            )
            public_key = hostsConf[machine]["config"]["settings"]["sshPublicKey"]

            for cmd, inputs, check in [
                (f"umount {device}*", None, False),
                (
                    f"dd if={image_file} of={device} bs=1M conv=fsync status=progress",
                    None,
                    True,
                ),
                (f"umount {device}*", None, False),
                (
                    f"{mount_cmd} $(ls {device}* | sort | tail -n 1) {temp_dir}",
                    None,
                    True,
                ),  # ! assumes the last partition is the one we want,None),
                (f"mkdir -p {temp_dir}/etc/ssh", None, True),
                (
                    f"mkdir -p {temp_dir}/var/lib",
                    None,
                    True,
                ),  # Needed when using impermanence
                (
                    f"cp {private_key_path} {temp_dir}/etc/ssh/ssh_host_ed25519_key",
                    None,
                    True,
                ),
                (f"chmod 600 {temp_dir}/etc/ssh/ssh_host_ed25519_key", None, True),
                (
                    f"tee {temp_dir}/etc/ssh/ssh_host_ed25519_key.pub",
                    public_key.encode(),
                    True,
                ),
                (f"chmod 644 {temp_dir}/etc/ssh/ssh_host_ed25519_key.pub", None, True),
            ]:
                print(f"sudo {cmd}")
                # TODO ideally, should run without a shell, but $(ls {device}* | sort | tail -n 1)
                subprocess.run(f"sudo {cmd}", input=inputs, check=check, shell=True)
            print(
                "INFO: The private key is stored in the SD card. Make sure to keep it safe."
            )
            print(
                f"Don't forget to update your SSH known hosts through a local system rebuild in order to be able to connect the current machine to {machine}."
            )
        finally:
            subprocess.run(
                f"sudo umount {device}*",
                check=False,
                shell=True,
                stderr=subprocess.PIPE,
            ),
            # TemporaryDirectory(delete=True) does not work for some reason
            shutil.rmtree(temp_dir)
