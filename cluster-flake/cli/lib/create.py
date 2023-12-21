from cryptography.hazmat.primitives import asymmetric
from jinja2 import Environment, FileSystemLoader
from lib.command import run_command
from lib.config import get_cluster_config
from lib.secrets import rekey_secrets, update_secret
from lib.ssh import private_key_to_string, public_key_to_string
import click
import inquirer
import ipaddress
import os


@click.command(help="Create a new machine in the cluster.")
@click.pass_context
@click.option(
    "--rekey",
    is_flag=True,
    default=False,
    help="Rekey the secrets after creating the machine configuration.",
)
# ? TODO add options
def create(ctx, rekey):
    ci = ctx.obj["CI"]
    if ci:
        print("CI mode is not supported yet for the 'create' command.")
        exit(1)
    conf = get_cluster_config(
        "cluster.hardware.nixos",
        "cluster.hardware.darwin",
        "cluster.hosts.nixosPath",
        "cluster.hosts.darwinPath",
        "cluster.secrets",
        "configs.*.config.settings.id",
        "configs.*.config.settings.localIP",
        "configs.*.config.settings.publicIP",
    )
    hostsConf = conf["configs"]
    clusterConf = conf["cluster"]
    hardware = clusterConf["hardware"]

    def validate_name(answers, current):
        if not current:
            raise inquirer.errors.ValidationError(
                "", reason="The name cannot be empty."
            )
        if current in hostsConf.keys():
            raise inquirer.errors.ValidationError(
                "", reason="The name is already taken."
            )
        return True

    def validate_public_ip(answers, current):
        if "bastion" not in answers["features"] and not current:
            # Empty values are allowed if the machine is not a bastion
            return True
        public_ips = [
            hostsConf[host]["config"]["settings"]["publicIP"] for host in hostsConf
        ]
        if current in public_ips:
            raise inquirer.errors.ValidationError("", reason="The IP is already taken.")
        try:
            ipaddress.IPv4Address(current)
            return True
        except ipaddress.AddressValueError:
            raise inquirer.errors.ValidationError("", reason="The IP is invalid.")

    def validate_local_ip(answers, current):
        if not current:
            # Local IP is optional
            return True
        public_ips = [
            hostsConf[host]["config"]["settings"]["localIP"] for host in hostsConf
        ]
        if current in public_ips:
            raise inquirer.errors.ValidationError("", reason="The IP is already taken.")
        try:
            ipaddress.IPv4Address(current)
            return True
        except ipaddress.AddressValueError:
            raise inquirer.errors.ValidationError("", reason="The IP is invalid.")

    # Only list systems that are defined in the config. If none defined, then raise an error.
    system_choices = []
    if clusterConf["hosts"]["nixosPath"]:
        system_choices.append(("NixOS", "nixos"))
    if clusterConf["hosts"]["darwinPath"]:
        system_choices.append(("Darwin", "darwin"))
    if not system_choices:
        print(
            "No host path is configured in the cluster configuration. Define at least one of the following: nixosHostsPath, darwinHostsPath"
        )
        exit(1)

    questions = [
        inquirer.Text(
            "name", message="What is the machine's name?", validate=validate_name
        ),
        inquirer.List(
            "system",
            message="Which system?",
            # If only one kind of system is available (nixos or darwin), then skip the question
            ignore=len(system_choices) == 1,
            default=system_choices[0][1] if len(system_choices) == 1 else None,
            choices=system_choices,
        ),
        inquirer.List(
            "hardware",
            message="Which hardware?",
            choices=lambda x: [("<None>", None)]
            + [
                (hardware[x["system"]][name]["description"], name)
                for name in hardware[x["system"]]
            ],
        ),
        inquirer.Checkbox(
            "features",
            message="Which features do you want to configure?",
            ignore=lambda x: x["system"] == "darwin",
            default=[],
            choices=[("Bastion", "bastion")],
        ),
        inquirer.Text(
            "local_ip", message="What is the local IP?", validate=validate_local_ip
        ),
        inquirer.Text(
            "public_ip",
            message="What is the public IP?",
            default=None,
            validate=validate_public_ip,
        ),
    ]

    variables = inquirer.prompt(questions)

    # Put the hosts path in the result
    host_path = clusterConf["hosts"]["%sPath" % (variables["system"])]

    # Generate a unique ID for the machine
    ids = [hostsConf[host]["config"]["settings"]["id"] for host in hostsConf]
    next_id = max(ids) + 1 if ids else 1
    variables["id"] = next_id

    # Generate a SSH private and public key
    ssh_private_key = asymmetric.ed25519.Ed25519PrivateKey.generate()

    ssh_private_key_file = "./ssh_%s_ed25519_key" % (variables["name"])
    with open(ssh_private_key_file, "w") as file:
        file.write(private_key_to_string(ssh_private_key))

    variables["ssh_public_key"] = public_key_to_string(ssh_private_key.public_key())

    # Generate a wireguard private and public key
    wg_private_key = run_command("wg genkey")
    wg_public_key = run_command(f"echo {wg_private_key} | wg pubkey")
    variables["wg_public_key"] = wg_public_key

    # TODO save the WG private key into a secret
    # add clusterAdmins public keys to the secrets so we will be able to edit the wg secret without reloading the cluster
    wg_secret_path = "%s/%s.wg.age" % (host_path, variables["name"])
    clusterConf["secrets"]["config"][wg_secret_path] = {
        "publicKeys": clusterConf["secrets"]["adminKeys"]
    }
    # then load the wg secret in the cluster
    update_secret(wg_secret_path, wg_private_key, clusterConf["secrets"]["config"])

    env = Environment(
        loader=FileSystemLoader(
            os.path.dirname(os.path.abspath(__file__)) + "/templates"
        )
    )
    # TODO trim_blocks=True, lstrip_blocks=True)

    # Now you can create templates and render them with trim_blocks enabled
    template = env.get_template("host.nix")
    rendered_output = template.render(variables)

    # Make sure the directory exists
    os.makedirs(os.path.dirname(host_path), exist_ok=True)

    host_nix_file = "%s/%s.nix" % (host_path, variables["name"])
    with open(host_nix_file, "w") as file:
        file.write(rendered_output)

    if rekey:
        # Finally, rekey the secrets with the new evaluated configuration
        os.system(f"git add {host_nix_file}")
        rekey_secrets()
        os.system("git add */*.age")
    else:
        print(
            "Secrets are not rekeyed yet, and the new host is not added to the git repository either."
        )

    print(
        f"Host created. Don't forget to keep its private key {ssh_private_key_file} in a safe place."
    )
