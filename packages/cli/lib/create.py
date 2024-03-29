from cryptography.hazmat.primitives import asymmetric
from jinja2 import Environment, FileSystemLoader
from lib.config import get_cluster_config, get_machines_config
from lib.ip import validateIp
from lib.secrets import rekey_secrets, generate_wireguard_keys
from lib.ssh import private_key_to_string, public_key_to_string
import click
import questionary
import os
import subprocess


@click.command(help="Create a new machine in the cluster.")
@click.argument("name", default="")
@click.option(
    "--rekey/--no-rekey",
    is_flag=True,
    default=True,
    help="Rekey the secrets after creating the machine configuration.",
)
@click.option(
    "--stage/--no-stage",
    is_flag=True,
    default=True,
    help="Stage the changes to git.",
)
def create(name, rekey, stage):
    clusterConf = get_cluster_config(
        "hardware",
        "builders",
        "wifi",
        "secrets",
        "adminKeys",
        "options.settings",
    )
    machines = get_machines_config(
        "*.config.settings.vpn.id",
        "*.config.settings.localIP",
        "*.config.settings.publicIP",
    )
    hostsConf = {k: v.config for k, v in machines.items()}

    hardware = clusterConf.hardware

    def validate_name_questionary(current):
        if not current:
            return "The name cannot be empty"
        if current in hostsConf.keys():
            return "The name is already taken."
        return True

    if validate_name_questionary(name) != True:
        name = questionary.text(
            "What is the machine's name?", validate=validate_name_questionary
        ).unsafe_ask()

    variables = {}
    variables["name"] = name
    try:
        variables["hardware"] = questionary.select(
            "Which hardware?",
            choices=sorted(
                [
                    questionary.Choice(value.label, value=name)
                    for name, value in hardware.items()
                ],
                key=lambda x: x.title,
            ),
        ).unsafe_ask()

        # 1. required options
        # 2. networking
        # 3. services

        variables["vpn"] = questionary.confirm(
            "Do you want to install the VPN?"
        ).unsafe_ask()

        available_features = []

        if variables["vpn"]:
            # Generate a unique ID for the machine
            ids = [
                host.settings.vpn.id
                for host in hostsConf.values()
                if host.settings.vpn.id
            ]
            next_id = max(ids) + 1 if ids else 1
            variables["id"] = next_id
            if variables["system"] == "nixos":
                available_features.append(
                    questionary.Choice("VPN server", value="bastion")
                )

        if clusterConf.builders.enable:
            available_features.append(
                questionary.Choice("Nix builder", value="builder")
            )
        if clusterConf.wifi.enable:
            available_features.append(questionary.Choice("Wifi", value="wifi"))

        variables["features"] = questionary.checkbox(
            "Which features do you want to configure?",
            choices=sorted(available_features, key=lambda x: x.title),
        ).unsafe_ask()

        if "bastion" in variables["features"]:
            variables["features"].append("vpn")
            taken_public_ips = [
                conf.settings.publicIP
                for conf in hostsConf.values()
                if conf.settings.publicIP is not None
            ]
            variables["public_ip"] = (
                questionary.text(
                    "What is the public IP?",
                    validate=lambda x: validateIp(x, taken=taken_public_ips),
                )
                .skip_if("bastion" not in variables["features"], None)
                .unsafe_ask()
            )

        # ? impermanence? other services?
        taken_local_ips = [
            conf.settings.localIP
            for conf in hostsConf.values()
            if conf.settings.localIP is not None
        ]

        variables["local_ip"] = questionary.text(
            "What is the local IP?",
            validate=lambda x: validateIp(x, taken=taken_local_ips, optional=True),
        ).unsafe_ask()

    except KeyboardInterrupt:
        print("Aborting...")
        exit(1)

    # Put the hosts path in the result
    host_path = clusterConf[variables["system"]].path

    # Generate a SSH private and public key
    ssh_private_key = asymmetric.ed25519.Ed25519PrivateKey.generate()

    ssh_private_key_file = "./ssh_%s_ed25519_key" % (variables["name"])
    with open(ssh_private_key_file, "w") as file:
        file.write(private_key_to_string(ssh_private_key))

    variables["ssh_public_key"] = public_key_to_string(ssh_private_key.public_key())

    if variables["vpn"]:
        # Generate a Wireguard private and public key
        wg_public_key = generate_wireguard_keys(
            host_path, variables["name"], clusterConf, stage
        )
        variables["wg_public_key"] = wg_public_key

    env = Environment(
        loader=FileSystemLoader(
            os.path.dirname(os.path.abspath(__file__)) + "/templates"
        )
    )

    template = env.get_template("host.nix")
    rendered_output = template.render(variables)

    # Make sure the directory exists
    os.makedirs(os.path.dirname(host_path), exist_ok=True)

    host_nix_file = "%s/%s.nix" % (host_path, variables["name"])
    with open(host_nix_file, "w") as file:
        file.write(rendered_output)
    if stage:
        # Finally, rekey the secrets with the new evaluated configuration
        subprocess.run(["git", "add", host_nix_file], check=True)
    if rekey:
        rekey_secrets(stage)

    else:
        print(
            "Secrets are not rekeyed yet, and the new host is not added to the git repository either."
        )

    print(
        f"Host created. Don't forget to keep its private key {ssh_private_key_file} in a safe place."
    )
    # TODO prompt git add
    # TODO prompt install
