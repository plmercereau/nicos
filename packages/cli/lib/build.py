from cryptography.hazmat.primitives import serialization
from lib.command import run_command
from lib.config import get_machines_config, OVERRIDE_FLAKE
from lib.ssh import public_key_to_string
from tempfile import TemporaryDirectory
import click
import os
import pathlib
import platform
import questionary
import shutil
import subprocess


@click.command(name="build", help="Build a machine ISO image.")
@click.argument("machine", default="")
@click.option(
    "--private-key-path",
    "-k",
    help="The path to the private key to use. Defaults to ssh_<machine>_ed25519_key.",
)
def build_sd_image(machine, private_key_path):
    hostsConf = get_machines_config(
        "*.config.sdImage.imageName",
        "*.config.settings.sshPublicKey",
    )

    sd_machine_choices = [k for k, v in hostsConf.items() if v.config.sdImage.imageName]

    if machine:
        if machine not in sd_machine_choices:
            print(
                "The machine %s does not have a SD image configuration. Please select one of the following machines: %s"
                % (machine, ", ".join(sd_machine_choices))
            )
            exit(1)
    else:
        machine = questionary.select(
            "Select the machine for the SD image to build",
            choices=sd_machine_choices,
        ).ask()
    if not machine:
        print("No machine selected.")
        exit(1)

    if not private_key_path:
        private_key_path = f"ssh_{machine}_ed25519_key"

    class KeyValidator(questionary.Validator):
        def validate(self, value):
            path = value if isinstance(value, str) else value.text()
            try:
                with open(path, "rb") as private_key_file:
                    private_key = serialization.load_ssh_private_key(
                        private_key_file.read(), password=None
                    )
                ssh_public_key = hostsConf[machine].config.settings.sshPublicKey
            except Exception:
                raise questionary.ValidationError(message=f"Error reading  {path}.")
            try:
                decoded_public_key = public_key_to_string(private_key.public_key())
            except Exception:
                raise questionary.ValidationError(
                    message=f"The file {path} is an invalid private key file."
                )
            if ssh_public_key != decoded_public_key:
                raise questionary.ValidationError(
                    message=f"The private key in {path} does not match the public key."
                )

    try:
        KeyValidator().validate(private_key_path)
    except questionary.ValidationError:
        private_key_path = questionary.path(
            "Select the private key to use",
            validate=KeyValidator,
        ).ask()

    with TemporaryDirectory() as temp_dir:
        try:
            print("Building the SD image...")
            image_name = hostsConf[machine].config.sdImage.imageName
            result = run_command(
                f"nix build .#nixosConfigurations.{machine}.config.system.build.sdImage --no-link --print-out-paths {OVERRIDE_FLAKE}"
            )
            files_dir = f"{temp_dir}/files"
            isLinux = platform.system() != "Darwin"

            ### Prepare the files ###
            pathlib.Path(f"{files_dir}/etc/ssh").mkdir(parents=True, exist_ok=True)
            # Needed when using impermanence
            pathlib.Path(f"{files_dir}/var/lib").mkdir(parents=True, exist_ok=True)
            # private key
            shutil.copy(private_key_path, f"{files_dir}/etc/ssh/ssh_host_ed25519_key")
            os.chmod(f"{files_dir}/etc/ssh/ssh_host_ed25519_key", 0o600)
            # public key
            with open(f"{files_dir}/etc/ssh/ssh_host_ed25519_key.pub", "w") as file:
                file.write(hostsConf[machine].config.settings.sshPublicKey)
            os.chmod(f"{files_dir}/etc/ssh/ssh_host_ed25519_key.pub", 0o644)

            drv_image_file = f"{result}/sd-image/{image_name}"

            if isLinux:
                local_image_path = f"{temp_dir}/{image_name}"
                remote_image_path = local_image_path
                remote_mount_path = f"{temp_dir}/mnt"
                pathlib.Path(remote_mount_path).mkdir()
            else:
                local_image_path = f"/run/org.nixos.linux-builder/xchg/{machine}.img"
                remote_image_path = f"/tmp/xchg/{machine}.img"
                remote_mount_path = "/tmp/xchg/mount"

            # Copy the image as we are about to modify it, and we don't want to modify the original in the Nix store
            subprocess.run(
                f"sudo cp -f {drv_image_file} {local_image_path}",
                shell=True,
                check=True,
            )

            # Mount the image
            through_ssh = "" if isLinux else "ssh builder@linux-builder"
            subprocess.run(
                f"""{through_ssh} bash -c '
                set -eo pipefail
                sudo mkdir -p {remote_mount_path}
                LOOP=$(sudo losetup --show -f -P {remote_image_path})
                sudo mount $(ls $LOOP* | tail -n1) {remote_mount_path}'
                """,
                check=True,
                shell=True,
                text=True,
            )

            remote_path = (
                remote_mount_path
                if isLinux
                else f"builder@linux-builder:{remote_mount_path}"
            )
            # Copy the files to the temporary directory
            subprocess.run(
                f"rsync -avz --rsync-path='sudo rsync' --chown=root:root {files_dir}/ {remote_path}",
                check=True,
                shell=True,
            )

            # Move the image to the current, and make sure it is owned by the current user
            output = f"{machine}.img"
            subprocess.run(
                f"sudo mv {local_image_path} {output}",
                check=True,
                shell=True,
            )
            subprocess.run(
                f"sudo chown {os.getuid()}:{os.getgid()} {output}",
                check=True,
                shell=True,
            )
            os.chmod(output, 0o644)

            print(
                f"The SD image for {machine} has been built successfully to {output}",
                "INFO: The private key is stored in the image. Make sure to keep the file safe.",
                sep=os.linesep,
            )
        finally:
            print("Cleaning up...")
            umount_command = f"sudo umount {remote_mount_path}"
            subprocess.run(
                f"{through_ssh} {umount_command}",
                shell=True,
                stderr=subprocess.PIPE,
            ),
            # TemporaryDirectory(delete=True) does not work for some reason
            shutil.rmtree(temp_dir)
