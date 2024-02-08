from cryptography.hazmat.primitives import asymmetric
from jinja2 import Environment, FileSystemLoader
from lib.secrets import update_secret, get_secrets_config
from lib.ssh import private_key_to_string, public_key_to_string
import click
import getpass
import json
import os
import questionary
import subprocess


def normalise_dir_path(dir_path):
    if not dir_path:
        return None
    # Normalize the path
    normalised_path = os.path.normpath(dir_path)

    # Prepend "./" if the path does not start with it or a drive letter (for Windows)
    if not (
        normalised_path.startswith((".", os.sep))
        or (os.name == "nt" and normalised_path[1:3] == ":\\")
    ):
        normalised_path = f".{os.sep}{normalised_path}"

    return normalised_path


def validate_path(path, variables):
    if not path:
        return "You must enter a path."
    if path.startswith(".."):
        return "The path must be within the current directory."
    if path.startswith("/"):
        return "The path must be relative to the current directory."
    if os.path.isfile(path):
        return "The path must be a directory."
    normalised = normalise_dir_path(path)
    for key, value in variables.items():
        if key.endswith("_path") and value and value == normalised:
            return f"The path must be different from {key}."
    return True


def get_all_ssh_public_keys():
    home_directory = os.path.expanduser(
        "~"
    )  # Gets the home directory of the current user
    ssh_directory = os.path.join(home_directory, ".ssh")  # Path to the .ssh directory

    if not os.path.exists(ssh_directory):
        return "SSH directory not found."

    public_keys = []
    for filename in os.listdir(ssh_directory):
        if (
            filename.startswith("id_")
            and filename.endswith(".pub")
            and not filename.endswith(".pem.pub")
        ):
            file_path = os.path.join(ssh_directory, filename)
            with open(file_path, "r") as file:
                algo, key, *_ = file.read().split(" ")
                public_keys.append(f"{algo} {key}")

    return public_keys


@click.command(help="Initialise a new cluster.")
@click.option(
    "--stage/--no-stage",
    is_flag=True,
    default=True,
    help="Stage the changes to git.",
)
def init(stage):
    variables = {}
    variables["user"] = getpass.getuser()
    variables["admin_keys"] = get_all_ssh_public_keys()

    try:
        variables["machines_path"] = normalise_dir_path(
            questionary.path(
                "Path to your NixOS machines",
                only_directories=True,
                validate=lambda x: validate_path(x, variables),
            ).unsafe_ask()
        )

        variables["users"] = questionary.confirm(
            "Will you configure users?"
        ).unsafe_ask()
        variables["users_path"] = normalise_dir_path(
            questionary.path(
                "Path to your users",
                only_directories=True,
                validate=lambda x: validate_path(x, variables),
            )
            .skip_if(not variables["users"])
            .unsafe_ask()
        )
        variables["wifi"] = questionary.confirm("Will you configure wifi?").unsafe_ask()
        variables["wifi_path"] = normalise_dir_path(
            questionary.path(
                "Path to your wifi",
                only_directories=True,
                validate=lambda x: validate_path(x, variables),
            )
            .skip_if(not variables["wifi"])
            .unsafe_ask()
        )
        variables["builders"] = questionary.confirm(
            "Will you configure shared Nix builders?"
        ).unsafe_ask()
        variables["builders_path"] = normalise_dir_path(
            questionary.path(
                "Path to your shared Nix builders",
                only_directories=True,
                validate=lambda x: validate_path(x, variables),
            )
            .skip_if(not variables["builders"])
            .unsafe_ask()
        )

    except KeyboardInterrupt:
        print("Aborting...")
        exit(1)

    subprocess.run(["git", "init", "."], check=True)

    env = Environment(
        loader=FileSystemLoader(
            os.path.dirname(os.path.abspath(__file__)) + "/templates"
        )
    )

    flake_template = env.get_template("flake.nix")
    rendered_flake = flake_template.render(variables)
    flake_file = "./flake.nix"
    with open(flake_file, "w") as file:
        file.write(rendered_flake)
        if stage:
            subprocess.run(["git", "add", flake_file], check=True)

    shared_template = env.get_template("shared.nix")
    rendered_shared = shared_template.render(variables)
    shared_file = "./shared.nix"
    with open(shared_file, "w") as file:
        file.write(rendered_shared)
        if stage:
            subprocess.run(["git", "add", shared_file], check=True)

    subprocess.run(["nix", "flake", "update"], check=True)

    for key, value in variables.items():
        if key.endswith("_path") and value:
            os.makedirs(value, exist_ok=True)
            git_keep = f"{value}/.gitkeep"
            with open(git_keep, "a"):
                pass
            if stage:
                subprocess.run(["git", "add", git_keep], check=True)

    config = get_secrets_config()

    # Generate wifi files
    if variables["wifi"]:
        wifi_path = variables["wifi_path"]
        update_secret(f"{wifi_path}/psk.age", "", config)
        with open(f"{wifi_path}/list.json", "w") as file:
            file.write(json.dumps([]))
        if stage:
            subprocess.run(["git", "add", wifi_path], check=True)

    # Generate builders files
    if variables["builders"]:
        builders_path = variables["builders_path"]
        # Generate a SSH private and public key
        ssh_private_key = asymmetric.ed25519.Ed25519PrivateKey.generate()
        # Encrypt the private key
        update_secret(
            f"{builders_path}/key.age", private_key_to_string(ssh_private_key), config
        )
        # Save the public key in plain text
        with open(f"{builders_path}/key.pub", "w") as file:
            file.write(public_key_to_string(ssh_private_key.public_key()))
        if stage:
            subprocess.run(["git", "add", builders_path], check=True)

    if stage:
        subprocess.run(["git", "add", "flake.lock"], check=True)

    print("Initialised successfully.")
    print("You can now create a new machine with the 'create' command.")
