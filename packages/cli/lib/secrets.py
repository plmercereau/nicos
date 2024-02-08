from lib.command import run_command
from lib.config import get_cluster_config, get_machines_config
from tempfile import NamedTemporaryFile
import bcrypt
import click
import json
import os
import questionary
import subprocess
import sys


def generate_wireguard_keys(host_path, hostname, clusterConf, stage=False):
    wg_private_key = run_command("wg genkey")
    wg_public_key = run_command(f'echo "{wg_private_key}" | wg pubkey')
    # save the WG private key into a secret
    # add clusterAdmins public keys to the secrets so we will be able to edit the wg secret without reloading the cluster
    wg_secret_path = "%s/%s.vpn.age" % (host_path, hostname)
    clusterConf.secrets[wg_secret_path] = {"publicKeys": clusterConf.adminKeys}
    # then load the wg secret in the cluster
    update_secret(wg_secret_path, wg_private_key, clusterConf.secrets)
    if stage:
        subprocess.run(["git", "add", wg_secret_path], check=True)
    return wg_public_key


def agenix_command(rules, args=[], editor=None):
    env_vars = os.environ.copy()
    if editor:
        env_vars["EDITOR"] = editor
    env_vars["RULES"] = rules
    result = subprocess.run(
        ["agenix"] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env_vars,
        check=True,
    )
    if result.stdout:
        print(result.stdout.decode(), file=sys.stderr)
    if result.stderr:
        print(result.stderr.decode(), file=sys.stderr)


def get_secrets_config():
    config = get_cluster_config("secrets").secrets
    if config is None:
        print("No secrets found in the cluster.", file=sys.stderr)
        exit(1)
    return config


def update_secret(path, value, cfg=None):
    with NamedTemporaryFile(delete=True) as temp_file:
        with open(temp_file.name, "w") as file:
            file.write(value)
        with AgenixRules(cfg) as rules:
            agenix_command(rules, ["-e", path], f"cp {temp_file.name}")


def rekey_secrets(stage=False):
    print("Rekeying the cluster", file=sys.stderr)
    config = get_secrets_config()
    with AgenixRules(config) as rules:
        agenix_command(rules, ["-r"])
    if stage:
        for path in config.keys():
            subprocess.run(["git", "add", path], check=True)


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
@click.option(
    "--stage/--no-stage",
    is_flag=True,
    default=True,
    help="Stage the changes to git.",
)
def rekey(stage):
    rekey_secrets(stage)


@click.command(help="Export the secrets config in the cluster as a JSON object")
def export():
    print(json.dumps(get_secrets_config(), indent=2))


@click.command(name="list", help="List the secrets in the cluster")
def list_secrets():
    """List the secrets in the cluster"""
    print("\n".join(get_secrets_config().keys()))


@click.command(help="Edit a secret")
@click.argument("path")
@click.option(
    "--stage/--no-stage",
    is_flag=True,
    default=True,
    help="Stage the changes to git.",
)
def edit(path, stage):
    # TODO make sure it works when creating a new file
    print(f"Editing {path}", file=sys.stderr)
    with AgenixRules() as rules:
        agenix_command(rules, ["-e", path])
    if stage:
        subprocess.run(["git", "add", path], check=True)


@click.command(help="Edit a user password")
@click.argument("name")
@click.argument("password", default="")
@click.option(
    "--stage/--no-stage",
    is_flag=True,
    default=True,
    help="Stage the changes to git.",
)
@click.option(
    "--force",
    is_flag=True,
    default=False,
    help="Force the change without prompt if the secret already exists.",
)
def user(name, password, stage, force):
    cfg = get_cluster_config("secrets", "users.path")
    file = f"{cfg.users.path}/{name}.hash.age"
    exists = os.path.isfile(file)
    if (
        exists
        and not force
        and not questionary.confirm(
            f"A password file for {name} already exists. Overwrite?"
        ).unsafe_ask()
    ):
        exit(1)
    if not password:
        password = questionary.password(
            "Password", validate=lambda x: "should not be empty" if not x else True
        ).unsafe_ask()
        config = questionary.password("Confirm password").unsafe_ask()
        if password != config:
            print("Passwords do not match.", file=sys.stderr)
            exit(1)
    print(
        f"Updating {name} password hash"
        if exists
        else f"Adding a new user {name} password hash",
        file=sys.stderr,
    )
    salt = bcrypt.gensalt(rounds=12)
    password_hash = bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")
    update_secret(file, password_hash, cfg.secrets)
    if stage:
        subprocess.run(["git", "add", file], check=True)


@click.command(help="Edit wifi networks and passwords")
@click.option(
    "--stage/--no-stage",
    is_flag=True,
    default=True,
    help="Stage the changes to git.",
)
def wifi(stage):
    cfg = get_cluster_config("secrets", "wifi.path")
    with AgenixRules(cfg.secrets) as rules:
        wifi_path = cfg.wifi.path
        agenix_command(rules, ["-e", f"{wifi_path}/psk.age"])
        result = run_command(f"RULES={rules} agenix -d {wifi_path}/psk.age")
        # Transform the key=value output into a JSON object
        parsed_data = {
            key.strip(): value.strip()
            for line in result.split("\n")
            if "=" in line  # only keep lines with =
            for key, value in [line.split("=", 1)]
        }
        with open(f"{wifi_path}/list.json", "w") as file:
            file.write(json.dumps(list(parsed_data.keys())))
    if stage:
        subprocess.run(["git", "add", f"{wifi_path}/psk.age"], check=True)
        subprocess.run(["git", "add", f"{wifi_path}/list.json"], check=True)


@click.command(help="Add or replace a Wireguard private key of a given host")
@click.argument("name", default="")
@click.option(
    "--stage/--no-stage",
    is_flag=True,
    default=True,
    help="Stage the changes to git.",
)
@click.option(
    "--force",
    is_flag=True,
    default=False,
    help="Force the change without prompt if the secret already exists.",
)
def vpn(name, stage, force):
    clusterConfig = get_cluster_config(
        "adminKeys",
        "secrets",
        "machinesPath",
    )
    machinesConfig = get_machines_config(
        "*.config.networking.hostName",
    )
    if name and not name in machinesConfig.keys():
        print(f"Host {name} not found in the cluster.", file=sys.stderr)
        exit(1)
    if not name:
        name = questionary.select(
            "Select the host", choices=list(machinesConfig.keys())
        ).unsafe_ask()

    host_path = clusterConfig.machinesPath
    file_path = f"{host_path}/{name}.vpn.age"
    # prompt if the file already exists
    if (
        os.path.isfile(file_path)
        and not force
        and not questionary.confirm(
            f"File {file_path} already exists. Overwrite?"
        ).unsafe_ask()
    ):
        exit(0)
    public_key = generate_wireguard_keys(host_path, name, clusterConfig, stage=stage)
    print(f"Private key of {name} generated and encoded.", file=sys.stderr)
    print(
        f"Don't forget to change `settings.networking.vpn.publicKey`:", file=sys.stderr
    )
    print(public_key)


@click.group(help="Manage the secrets for the cluster")
def secrets():
    pass


secrets.add_command(rekey)
secrets.add_command(export)
secrets.add_command(list_secrets)
secrets.add_command(edit)
secrets.add_command(user)
secrets.add_command(wifi)
secrets.add_command(vpn)
