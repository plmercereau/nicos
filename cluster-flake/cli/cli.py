#! /usr/bin/env python

from cryptography.hazmat.primitives import asymmetric, serialization
from run import run_command
from jinja2 import  Environment, FileSystemLoader
from agenix import rekey_secrets, update_secret, Secrets

from config import get_cluster_config
import fire
import glob
import inquirer
import ipaddress
import os
import sys

class CLI(object):
    def __init__(self):
        self.secrets = Secrets()

    def deploy(self, machines = [], all=False):
        """Deploy one or several machines"""
        if isinstance(machines, str): machines = [machines] # ! In python fire, when there is only one argument, it is a string
        cfg = get_cluster_config(["hosts.nixosPath", "hosts.darwinPath"])["hosts"]

        def host_names(hostsPath):
            if hostsPath is None: return []
            return [os.path.splitext(os.path.basename(file))[0] for file in glob.glob(f"{hostsPath}/*.nix")]
        
        darwinHosts = host_names(cfg["darwinPath"])
        nixosHosts = host_names(cfg["nixosPath"])
        choices = sorted(nixosHosts + darwinHosts)

        if (all):
            machines = choices

        if not machines:                
            questions = [
                inquirer.Checkbox('hosts',
                            message="Which host do you want to deploy?",
                            choices=choices
                        ),
            ]
            machines = inquirer.prompt(questions)["hosts"]
        
        if not machines:
            print("No machine to deploy")
            return
        
        print(f"Deploying {machines}")
        targets = [f".#{machine}" for machine in machines]
        os.system(f"nix run github:serokell/deploy-rs -- --targets {' '.join(targets)}")
    
    def create(self, rekey=True):
        """Create a machine"""
        cfg = get_cluster_config(["hardware.nixos", 
                                  "hardware.darwin", 
                                  "hosts.settings", 
                                  "hosts.nixosPath", 
                                  "hosts.darwinPath", 
                                  "secrets"])
        settings = cfg["hosts"]["settings"]
        hardware = cfg["hardware"]

        def validate_name(answers, current):
            if not current:
                raise inquirer.errors.ValidationError('', reason='The name cannot be empty.')
            if current in settings.keys():
                raise inquirer.errors.ValidationError('', reason='The name is already taken.')
            return True
        
        def validate_public_ip(answers, current):
            if "bastion" not in answers["features"] and not current: 
                # Empty values are allowed if the machine is not a bastion
                return True
            public_ips = [settings[host]["publicIP"] for host in settings]
            if current in public_ips:
                raise inquirer.errors.ValidationError('', reason='The IP is already taken.')
            try:
                ipaddress.IPv4Address(current)
                return True
            except ipaddress.AddressValueError:
                raise inquirer.errors.ValidationError('', reason='The IP is invalid.')


        def validate_local_ip(answers, current):
            if not current: 
                # Local IP is optional
                return True
            public_ips = [settings[host]["localIP"] for host in settings]
            if current in public_ips:
                raise inquirer.errors.ValidationError('', reason='The IP is already taken.')
            try:
                ipaddress.IPv4Address(current)
                return True
            except ipaddress.AddressValueError:
                raise inquirer.errors.ValidationError('', reason='The IP is invalid.')

        # Only list systems that are defined in the config. If none defined, then raise an error. 
        system_choices = []
        if cfg["hosts"]["nixosPath"]: system_choices.append(("NixOS", "nixos"))
        if cfg["hosts"]["darwinPath"]: system_choices.append(("Darwin", "darwin"))
        if not system_choices: 
            print("No host path is configured in the cluster configuration. Define at least one of the following: nixosHostsPath, darwinHostsPath")
            sys.exit(1)

        questions = [
                inquirer.Text('name', 
                            message="What is the machine's name?", 
                            validate=validate_name),
                inquirer.List('system',
                            message="Which system?",
                            # If only one kind of system is available (nixos or darwin), then skip the question
                            ignore = len(system_choices) == 1,
                            default = system_choices[0][1] if len(system_choices) == 1 else None,
                            choices=system_choices
                        ),
                inquirer.List('hardware',
                            message="Which hardware?", 
                            choices= lambda x: [("<None>", None)] + [(hardware[x["system"]][name]["description"], name) for name in hardware[x["system"]]],
                    ),
                inquirer.Checkbox('features',
                            message="Which features do you want to configure?",
                            ignore = lambda x: x["system"] == "darwin",
                            default = [],
                            choices=[("Bastion", "bastion")]
                    ),
                inquirer.Text('local_ip', 
                            message = "What is the local IP?",
                            validate=validate_local_ip),
                inquirer.Text('public_ip',
                            message = "What is the public IP?",
                            default = None,
                            validate=validate_public_ip),
            ]
    
        variables = inquirer.prompt(questions)

        # Put the hosts path in the result
        host_path = cfg.get("hosts").get(variables.get("system") + "Path")

        # Generate a unique ID for the machine
        ids = [settings[host]["id"] for host in settings]
        next_id = max(ids) + 1 if ids else 1
        variables["id"] = next_id

        # Generate a SSH private and public key
        ssh_private_key = asymmetric.ed25519.Ed25519PrivateKey.generate()

        ssh_private_key_file = f"./ssh_{variables.get('name')}_ed25519_key"
        with open(ssh_private_key_file, "w") as file:
            # TODO something is wrong here
            file.write(ssh_private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.OpenSSH,
            encryption_algorithm=serialization.NoEncryption()).decode('utf-8'))
        
        variables["ssh_public_key"] = ssh_private_key.public_key().public_bytes(
            encoding=serialization.Encoding.OpenSSH,
            format=serialization.PublicFormat.OpenSSH).decode('utf-8')

        # Generate a wireguard private and public key
        wg_private_key = run_command("wg genkey")
        wg_public_key = run_command(f"echo {wg_private_key} | wg pubkey")
        variables["wg_public_key"] = wg_public_key

        # TODO save the WG private key into a secret
        # add clusterAdmins public keys to the secrets so we will be able to edit the wg secret without reloading the cluster
        wg_secret_path = f"{host_path}/{variables.get('name')}.wg.age"
        cfg["secrets"]["config"][wg_secret_path] = {'publicKeys' : cfg.get("secrets").get("adminKeys")}
        # then load the wg secret in the cluster
        update_secret(wg_secret_path, wg_private_key, cfg)

        env = Environment(loader=FileSystemLoader(os.path.dirname(os.path.abspath(__file__)) + '/templates'))
        # TODO trim_blocks=True, lstrip_blocks=True)

        # Now you can create templates and render them with trim_blocks enabled
        template = env.get_template('host.nix')
        rendered_output = template.render(variables)
        
        # Make sure the directory exists
        os.makedirs(os.path.dirname(host_path), exist_ok=True)

        host_nix_file = f"{host_path}/{variables.get('name')}.nix"
        with open(host_nix_file, "w") as file:
            file.write(rendered_output)

        if rekey:
            # Finally, rekey the secrets with the new evaluated configuration
            os.system(f"git add {host_nix_file}")
            rekey_secrets()
            os.system("git add */*.age")
        else:
            print("Secrets are not rekeyed yet, and the new host is not added to the git repository either.")
            
        print(f"Host created. Don't forget to keep its private key {ssh_private_key_file} in a safe place.")
    
    def build(self, machine):
        """Build a machine ISO image"""
        """ TODO implement
        - 
        """
        return
    
if __name__ == '__main__':
  fire.Fire(CLI)
