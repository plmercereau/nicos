from cryptography.hazmat.primitives import asymmetric
from jinja2 import Environment, FileSystemLoader
from lib.command import run_command
from lib.config import get_cluster_config
from lib.ip import IpValidator
from lib.secrets import rekey_secrets, update_secret
from lib.ssh import private_key_to_string, public_key_to_string
import click
import questionary
import os


@click.command(help="Create a new machine in the cluster.")
@click.pass_context
@click.argument("name", default="")
@click.option(
    "--rekey/--no-rekey",
    is_flag=True,
    default=True,
    help="Rekey the secrets after creating the machine configuration.",
)
def create(ctx, name, rekey):
    ci = ctx.obj["CI"]
    if ci:
        print("CI mode is not supported yet for the 'create' command.")
        exit(1)
    conf = get_cluster_config(
        "cluster.hardware.nixos",
        "cluster.hardware.darwin",
        "cluster.nixos.path",
        "cluster.darwin.path",
        "cluster.secrets",
        "cluster.adminKeys",
        "cluster.options.nixos.settings",
        "cluster.options.darwin.settings",
        "configs.*.config.settings.networking.vpn.id",
        "configs.*.config.settings.networking.localIP",
        "configs.*.config.settings.networking.publicIP",
    )
    hostsConf = conf.configs
    clusterConf = conf.cluster
    hardware = clusterConf.hardware
    options = clusterConf.options
    # TODO for later
    # def recurse_options(opts):
    #     for key, value in opts.items():
    #         if isinstance(value, dict) and not hasattr(value, "path"):
    #             recurse_options(value)
    #         else:
    #             print(value.path)

    # recurse_options(options.nixos.settings)

    def check_name(n):
        if n in hostsConf.keys():
            return "The name is already taken."
        return False

    def validate_name_questionary(current):
        if not current:
            raise questionary.ValidationError(message="The name cannot be empty.")
        check = check_name(current)
        if check:
            raise questionary.ValidationError(message=check)

    # Only list systems that are defined in the config. If none defined, then raise an error.
    system_choices = []
    if clusterConf.nixos.path:
        system_choices.append(questionary.Choice("NixOS", value="nixos"))
    if clusterConf.darwin.path:
        system_choices.append(questionary.Choice("Darwin", value="darwin"))
    if not system_choices:
        print(
            "No host path is configured in the cluster configuration. Define at least one of the following: nixos.path, darwi.path"
        )
        exit(1)

    if name:
        # TODO not ideal
        check_name(name)
    else:
        name = questionary.text(
            "What is the machine's name?", validate=validate_name_questionary
        ).unsafe_ask()

    variables = {}
    variables["name"] = name
    try:
        variables["system"] = (
            questionary.select(
                "Which system?",
                choices=system_choices,
            )
            .skip_if(len(system_choices) == 1, system_choices[0].value)
            .unsafe_ask()
        )

        variables["hardware"] = questionary.select(
            "Which hardware?",
            choices=[
                questionary.Choice(value.label, value=name)
                for name, value in hardware[variables["system"]].items()
            ],
        ).unsafe_ask()

        # TODO -----> put the options/features here!!!
        # TODO make "settings.networking.vpn.publicKey" a required option - but skip it in the questions as it is generated
        # 1. required options
        # 2. networking
        # 3. services
        # 4. impermanence?
        variables["features"] = (
            questionary.checkbox(
                "Which features do you want to configure?",
                choices=[questionary.Choice("Bastion", value="bastion")],
            )
            .skip_if(variables["system"] == "darwin", [])
            .unsafe_ask()
        )

        variables["local_ip"] = questionary.text(
            "What is the local IP?",
            validate=IpValidator,  # TODO validate: not already taken
        ).unsafe_ask()

        variables["public_ip"] = (
            questionary.text(
                "What is the public IP?",
                validate=IpValidator,  # TODO validate: not already taken
            )
            .skip_if("bastion" not in variables["features"], None)
            .unsafe_ask()
        )
    except KeyboardInterrupt:
        print("Aborting...")
        exit(1)

    # Put the hosts path in the result
    host_path = clusterConf[variables["system"]].path

    # Generate a unique ID for the machine
    ids = [host.config.settings.networking.vpn.id for host in hostsConf.values()]
    next_id = max(ids) + 1 if ids else 1
    variables["id"] = next_id

    # Generate a SSH private and public key
    ssh_private_key = asymmetric.ed25519.Ed25519PrivateKey.generate()

    ssh_private_key_file = "./ssh_%s_ed25519_key" % (variables["name"])
    with open(ssh_private_key_file, "w") as file:
        file.write(private_key_to_string(ssh_private_key))

    variables["ssh_public_key"] = public_key_to_string(ssh_private_key.public_key())

    # Generate a Wireguard private and public key
    wg_private_key = run_command("wg genkey")
    wg_public_key = run_command(f'echo "{wg_private_key}" | wg pubkey')
    variables["wg_public_key"] = wg_public_key

    # TODO save the WG private key into a secret
    # add clusterAdmins public keys to the secrets so we will be able to edit the wg secret without reloading the cluster
    wg_secret_path = "%s/%s.vpn.age" % (host_path, variables["name"])
    clusterConf.secrets[wg_secret_path] = {"publicKeys": clusterConf.adminKeys}
    # then load the wg secret in the cluster
    update_secret(wg_secret_path, wg_private_key, clusterConf.secrets)

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

    # TODO prompt rekey
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
    # TODO prompt git add
    # TODO prompt install
