#! /usr/bin/env python

import fire
import glob
import inquirer
import os
import secrets
import config


class CLI(object):
    def __init__(self):
        self.secrets = secrets.Secrets()

    def deploy(self, machines = [], all=False):
        """Deploy one or several machines"""
        if isinstance(machines, str): machines = [machines] # ! In python fire, when there is only one argument, it is a string
        cfg = config.get_cluster_config(["hosts.nixosPath", "hosts.darwinPath"]).get("hosts")

        def host_names(hostsPath):
            if hostsPath is None: return []
            return [os.path.splitext(os.path.basename(file))[0] for file in glob.glob(f"{hostsPath}/*.nix")]
        
        darwinHosts = host_names(cfg.get("darwinPath"))
        nixosHosts = host_names(cfg.get("nixosPath"))
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
            machines = inquirer.prompt(questions).get("hosts")
        
        if not machines:
            print("No machine to deploy")
            return
        
        print(f"Deploying {machines}")
        targets = [f".#{machine}" for machine in machines]
        os.system(f"nix run github:serokell/deploy-rs -- --targets {' '.join(targets)}")
    
    def create(self):
        """Deploy a machine"""
        """ TODO implement
        - ask for the machine name (check if it is available)
        - ask for the machine type (darwin or nixos)
        - ask for the hardware type
        - get the next available id
        - get a public IP + validate it
        - get a local IP + validate it
        - settings to activate: bastion, ...
        - generate an ssh private + public key (use paramiko)
        - generate a wg private + public key
        - rekey agenix
        - message: keep the ssh private key safe + don't forget to git add .
        """
        return
    
    def build(self, machine):
        """Build a machine ISO image"""
        """ TODO implement
        - 
        """
        return
    
if __name__ == '__main__':
  fire.Fire(CLI)
