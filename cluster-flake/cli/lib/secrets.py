from lib.command import run_command
from lib.config import get_cluster_config
import bcrypt
import click
import json
import os
from tempfile import NamedTemporaryFile


def get_secrets_config():
    return get_cluster_config("cluster.secrets").cluster.secrets


def update_secret(path, value, cfg=None):
    with NamedTemporaryFile(delete=True) as temp_file:
        with open(temp_file.name, "w") as file:
            file.write(value)
        with AgenixRules(cfg) as rules:
            os.system(f"EDITOR='cp {temp_file.name}' RULES={rules} agenix -e {path}")


def rekey_secrets():
    print("Rekeying the cluster")
    with AgenixRules() as rules:
        os.system(f"RULES={rules} agenix -r")


class AgenixRules:
    def __init__(self, config=None):
        self.config = config

    def __enter__(self):
        if self.config is None:
            self.config = get_secrets_config()
        with NamedTemporaryFile(delete=False) as temp_file:
            self.rules = temp_file.name
            # Put the secrets in a temporary file as a nix expression
            with open(self.rules, "w") as file:
                jsonRules = self.config
                file.write("builtins.fromJSON ''%s''" % (json.dumps(jsonRules)))
        return self.rules

    def __exit__(self, exc_type, exc_value, traceback):
        os.remove(self.rules)


@click.command(name="rekey", help="Rekey all the secrets in the cluster.")
def rekey():
    rekey_secrets()


@click.command(help="Export the secrets config in the cluster as a JSON object")
def export():
    print(json.dumps(get_secrets_config(), indent=2))


@click.command(name="list", help="List the secrets in the cluster")
def list_secrets():
    """List the secrets in the cluster"""
    print("\n".join(get_secrets_config().keys()))


@click.command(help="Edit a secret")
@click.argument("path")
def edit(path):
    """Edit a secret"""
    print(f"Editing {path}")
    with AgenixRules() as rules:
        os.system(f"RULES={rules} agenix -e {path}")


@click.command(help="Add a user password")
@click.argument("name")
@click.argument("password")
def user(name, password):
    """Add a user password"""
    # TODO test this, but with a mock user or with madhu/kid on pi4g
    print(f"Adding a new user {name} password hash")
    cfg = get_cluster_config("cluster.secrets", "cluster.users.path").cluster
    salt = bcrypt.gensalt(rounds=12)
    password_hash = bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")
    update_secret(f"{cfg.users.path}/{name}.hash.age", password_hash, cfg.secrets)


@click.command(help="Add a wifi password")
def wifi():
    """Add a wifi password"""
    cfg = get_cluster_config("cluster.secrets", "cluster.wifi.path").cluster
    with AgenixRules(cfg.secrets) as rules:
        wifi_path = cfg.wifi.path
        os.system(f"RULES={rules} agenix -e {wifi_path}/psk.age")
        result = run_command(f"RULES={rules} agenix -d {wifi_path}/psk.age")
        # Transform the key=value output into a JSON object
        parsed_data = {
            key.strip(): value.strip()
            for line in result.split("\n")
            for key, value in [line.split("=", 1)]
        }
        with open(f"{wifi_path}/list.json", "w") as file:
            file.write(json.dumps(list(parsed_data.keys())))


@click.group(help="Manage the secrets for the cluster")
@click.pass_context
def secrets(ctx):
    pass


secrets.add_command(rekey)
secrets.add_command(export)
secrets.add_command(list_secrets)
secrets.add_command(edit)
secrets.add_command(user)
secrets.add_command(wifi)
