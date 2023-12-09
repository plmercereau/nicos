#! /usr/bin/env python

import bcrypt
import fire
import json
import os
import subprocess
import sys
import tempfile

def flake_eval(flake = ".", attr_path = "", toJson = False):
    result = subprocess.run(f"nix eval {flake}#{attr_path} {'--json' if toJson else '--raw'} --quiet", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        # Handle the error
        error_message = result.stderr
        print(f"Error evaluating the cluster secrets: {error_message}")
        sys.exit(1)
    return json.loads(result.stdout) if toJson else result.stdout.strip()

def get_users_path():
    """Get the path to the users file"""
    return flake_eval(attr_path ="cluster.users.path")

class AgenixRules:
    def __enter__(self):
        # get the secrets from the flake in the current directory
        result = flake_eval(attr_path ="cluster.secrets", toJson=True)
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            rules = temp_file.name
            # Put the secrets in a temporary file as a nix expression
            with open(rules, "w") as file:
                file.write(f"builtins.fromJSON ''{json.dumps(result)}''")
        self.rules = rules
        return self.rules

    def __exit__(self, exc_type, exc_value, traceback):
        os.remove(self.rules)

class UpdateSecret:
    """Add a new secret to the cluster"""
    def user(self, name, password):
        """Add a user password"""
        # TODO test this, but with a mock user or with madhu/kid on pi4g
        print(f"Adding a new user {name} password hash")
        with tempfile.NamedTemporaryFile(delete=True) as temp_file:
            # Put the secrets in a temporary file as a nix expression
            with open(temp_file.name, "w") as file:
                salt = bcrypt.gensalt(rounds=12)
                password_hash = bcrypt.hashpw(password.encode('utf-8'), salt)
                file.write(password_hash.decode('utf-8'))
            with AgenixRules() as rules:
                users_path = get_users_path()
                os.system(f"EDITOR='cp {temp_file.name}' RULES={rules} agenix -e {users_path}/{name}.hash.age")
    
    def wifi(self, ssid, password):
        """Add a wifi password"""
        # TODO: Implement this
        return 
        # print(f"Adding a new wifi {ssid} password")
        # with tempfile.NamedTemporaryFile(delete=True) as temp_file:
        #     # Put the secrets in a temporary file as a nix expression
        #     with open(temp_file.name, "w") as file:
        #         file.write(password)
        #     with AgenixRules() as rules:
        #         os.system(f"EDITOR='cp {temp_file.name}' RULES={rules} agenix -e cluster.secrets.wifi.{ssid}.password")

class Secrets(object):
    """Manage the secrets for the cluster"""
    def __init__(self):
        self.update = UpdateSecret()

    def rekey(self):
        """Rekey all the secrets in the cluster"""
        print("Rekeying the cluster")
        with AgenixRules() as rules:
            os.system(f"RULES={rules} agenix -r")
    
    def export(self):
        """Export the secrets config in the cluster as a JSON object"""
        secrets = flake_eval(attr_path ="cluster.secrets", toJson=True)
        print (json.dumps(secrets, indent=2))

    def edit(self, path):
        """Edit a secret"""
        print(f"Editing {path}")
        with AgenixRules() as rules:
            os.system(f"RULES={rules} agenix -e {path}")

class CLI(object):
    def __init__(self):
        self.secrets = Secrets()

    # TODO: find a Fire alternative that prints a better help: I don't want --no_darwin or --nodarwin, I want --no-darwin
    def deploy(self, machines, all=False, darwin=True, nixos=True):
        """Create one or several machines"""
        # TODO implement
        print(f"Deploying {machines} {darwin} {nixos}")
        return
    
    def create(self):
        """Deploy a machine"""
        # TODO implement
        return
    
    def build(self, machine):
        """Build a machine ISO image"""
        # TODO implement, but only for raspberry for now
        return
    
if __name__ == '__main__':
  fire.Fire(CLI)
