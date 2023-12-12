import bcrypt
import json
import os
import subprocess
import sys
import tempfile
import config

class AgenixRules:
    def __init__(self, cluster = None):
        self.cluster = cluster

    def __enter__(self):
        if self.cluster is None:
            self.cluster = config.get_cluster_config(["secrets"])
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            self.rules = temp_file.name
            # Put the secrets in a temporary file as a nix expression
            with open(self.rules, "w") as file:
                jsonRules = self.cluster.get("secrets").get("config")
                file.write(f"builtins.fromJSON ''{json.dumps(jsonRules)}''")
        return self.rules

    def __exit__(self, exc_type, exc_value, traceback):
        os.remove(self.rules)


class Secrets(object):
    """Manage the secrets for the cluster"""
    def __init__(self):
        pass

    def rekey(self):
        """Rekey all the secrets in the cluster"""
        print("Rekeying the cluster")
        with AgenixRules() as rules:
            os.system(f"RULES={rules} agenix -r")
    
    def export(self):
        """Export the secrets config in the cluster as a JSON object"""
        secrets = config.get_cluster_config(["secrets.config"]).get("secrets").get("config")
        print (json.dumps(secrets, indent=2))

    def list(self):
        """List the secrets in the cluster"""
        secrets = config.get_cluster_config(["secrets.config"]).get("secrets").get("config")
        names = secrets.keys()
        print ("\n".join(names))

    def edit(self, path):
        """Edit a secret"""
        print(f"Editing {path}")
        with AgenixRules() as rules:
            os.system(f"RULES={rules} agenix -e {path}")

    def user(self, name, password):
        """Add a user password"""
        # TODO test this, but with a mock user or with madhu/kid on pi4g
        print(f"Adding a new user {name} password hash")
        cfg = config.get_cluster_config(["secrets", "users.path"])
        with tempfile.NamedTemporaryFile(delete=True) as temp_file:
            # Put the secrets in a temporary file as a nix expression
            with open(temp_file.name, "w") as file:
                salt = bcrypt.gensalt(rounds=12)
                password_hash = bcrypt.hashpw(password.encode('utf-8'), salt)
                file.write(password_hash.decode('utf-8'))
            with AgenixRules(cfg) as rules:
                users_path = cfg.get("users").get("path")
                os.system(f"EDITOR='cp {temp_file.name}' RULES={rules} agenix -e {users_path}/{name}.hash.age")

    def wifi(self):
        """Add a wifi password"""
        cfg = config.get_cluster_config(["secrets", "wifi.path"])
        with AgenixRules(cfg) as rules:
            wifi_path = cfg.get("wifi").get("path")
            os.system(f"RULES={rules} agenix -e {wifi_path}/psk.age")
            result = subprocess.run(f"RULES={rules} agenix -d {wifi_path}/psk.age", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if result.returncode != 0:
                error_message = result.stderr
                print(f"Error evaluating the wifi secrets: {error_message}")
                sys.exit(1)
            # Transform the key=value output into a JSON object
            parsed_data = {key.strip(): value.strip() for line in result.stdout.strip().split('\n') for key, value in [line.split('=', 1)]}
            with open(f"{wifi_path}/list.json", "w") as file:
                file.write(json.dumps(list(parsed_data.keys())))