from cryptography.hazmat.primitives import serialization
from lib.command import run_command
from lib.config import get_cluster_config
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
@click.pass_context
@click.argument("machine", default="")
@click.option(
    "--private-key-path",
    "-k",
    help="The path to the private key to use. Defaults to ssh_<machine>_ed25519_key.",
)
def build_sd_image(ctx, machine, private_key_path):
    ci = ctx.obj["CI"]

    hostsConf = get_cluster_config(
        "nixosConfigurations.*.config.sdImage.imageName",
        "nixosConfigurations.*.config.settings.sshPublicKey",
    ).nixosConfigurations

    sd_machine_choices = [k for k, v in hostsConf.items() if v.config.sdImage.imageName]

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
        if ci:
            exit(1)
        private_key_path = questionary.path(
            "Select the private key to use",
            validate=KeyValidator,
        ).ask()

    with TemporaryDirectory() as temp_dir:
        try:
            print("Building the SD image...")
            image_name = hostsConf[machine].config.sdImage.imageName
            result = run_command(
                f"nix build .#nixosConfigurations.{machine}.config.system.build.sdImage --no-link --print-out-paths"
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
                ["sudo", "cp", "-f", drv_image_file, local_image_path],
                check=True,
            )

            # Mount the image
            mount_command = [
                "sudo",
                "mount-image",
                remote_image_path,
                remote_mount_path,
            ]
            subprocess.run(
                mount_command
                if isLinux
                else [
                    "ssh",
                    "builder@linux-builder",
                    " ".join(mount_command),
                ],
                check=True,
            )

            # Copy the files to the temporary directory
            subprocess.run(
                [
                    "rsync",
                    "-avz",
                    "--rsync-path=sudo rsync",
                    "--chown=root:root",
                    f"{files_dir}/",
                    remote_mount_path
                    if isLinux
                    else f"builder@linux-builder:{remote_mount_path}",
                ],
                check=True,
            )

            # Move the image to the current, and make sure it is owned by the current user
            output = f"{machine}.img"
            subprocess.run(
                ["sudo", "mv", local_image_path, output],
                check=True,
            )
            subprocess.run(
                ["sudo", "chown", f"{os.getuid()}:{os.getgid()}", output],
                check=True,
            )
            os.chmod(output, 0o644)

            print(
                f"The SD image for {machine} has been built successfully to {output}",
                "INFO: The private key is stored in the image. Make sure to keep the file safe.",
                sep=os.linesep,
            )
        finally:
            print("Cleaning up...")
            umount_command = ["sudo", "umount", remote_mount_path]
            subprocess.run(
                umount_command
                if isLinux
                else [
                    "ssh",
                    "builder@linux-builder",
                    " ".join(umount_command),
                ],
                stderr=subprocess.PIPE,
            ),
            # TemporaryDirectory(delete=True) does not work for some reason
            shutil.rmtree(temp_dir)
