from cryptography.hazmat.primitives import serialization
from tempfile import TemporaryDirectory
from lib.config import get_cluster_config
from lib.ssh import public_key_to_string
import inquirer


def build_sd_image():

    clusterConf = get_cluster_config(["hosts.config.sdImage.imageName", "hosts.config.settings.sshPublicKey"])
    hostsConf = clusterConf["hosts"]["config"]
    sdMachines = [x for x in hostsConf if hostsConf[x]["sdImage"]["imageName"]]
    
    machine = inquirer.prompt(
         [inquirer.List('machine', message="Select the machine for the SD image to build", choices=sdMachines)]
         ).get("machine")

    private_key_path = f"ssh_{machine}_ed25519_key"

    def validate_key_path(_, current):
        try:
            with open(current, 'rb') as private_key_file:
                private_key = serialization.load_ssh_private_key(private_key_file.read(), password=None)
        except Exception:
            raise inquirer.errors.ValidationError('', reason=f'The file {current} is an invalid private key file.')

        ssh_public_key = hostsConf[machine]["settings"]["sshPublicKey"]
        if (ssh_public_key == public_key_to_string(private_key.public_key())):
            return True
        raise inquirer.errors.ValidationError('', reason=f"The private key in {current} does not match the public key.")


    try:
        validate_key_path({}, private_key_path)
    except inquirer.errors.ValidationError as e:
        print(e.reason)
        private_key_path = inquirer.prompt([
            inquirer.Path('private_key_path',
                            message="Select the private key to use",
                            validate = validate_key_path,
                            exists=True,
                            path_type=inquirer.Path.FILE
                )
        ]).get("private_key_path")
    
    # TODO continue
    print("validated:", machine, private_key_path)
    device = "TODO" # TODO
    with TemporaryDirectory(delete=True) as temp_dir:
        image_file="TODO" #TODO (nix build $".#nixosConfigurations.($host).config.system.build.sdImage" --no-link --print-out-paths) + $"/sd-image/($host).img"
        mount_cmd = "/usr/local/sbin/mount_ufsd_ExtFS" # TODO
        os_partition = # TODO $os_partition = (ls $"($device)*" | get name | sort | last)
    # let $temp_mount = (mktemp --directory)

        sudo_commands = [
            f"umount {device}*"
            f"dd if={image_file} of={device} bs=1M conv=fsync status=progress"
            f"umount {device}*"
            f"{mount_cmd} {os_partition} {temp_dir}"
            f"mkdir -p {temp_dir}/etc/ssh"
    # Needed when using impermanence
            f"mkdir -p {temp_dir}/var/lib"
            f"cp {private_key_path} {temp_dir}/etc/ssh/ssh_host_ed25519_key"
            f"chmod 600 {temp_dir}/etc/ssh/ssh_host_ed25519_key"
            f"echo {TODO PUBLIC KEY} > {temp_dir}/etc/ssh/ssh_host_ed25519_key.pub"
            f"chmod 644 {temp_dir}/etc/ssh/ssh_host_ed25519_key.pub"
            f"umount {device}*"
        ]
        # TODO exec sudo commands
    print("INFO: The private key is stored in the SD card. Make sure to keep it safe.")
    print(f"Don't forget to update your SSH known hosts through a local system rebuild in order to be able to connect the current machine to {machine}.")