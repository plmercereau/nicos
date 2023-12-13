from cryptography.hazmat.primitives import serialization
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