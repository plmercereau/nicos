@_default:
    just --list

# Run a nix build command and link the result from <subpath>/* to ./output/
nix-build target subpath=".":
    #!/usr/bin/env sh
    set -e
    # TODO the --impure flag should be removed once we don't load the wifi secret when bootstraping sd-images anymore
    RESULT=$(nix build {{target}} --no-link --print-out-paths --impure)/{{subpath}}
    mkdir -p ./output
    ln -sf $RESULT/* ./output/
    echo "Result: ./output/$(ls $RESULT)"

# Build a Raspberry Pi Zero 2w SD image using Docker
bootstrap-build-zero2: (nix-build ".#packages.aarch64-linux.zero2-installer" "sd-image" )

# Build a Raspberry Pi 4 SD image using Docker
bootstrap-build-pi4: (nix-build ".#packages.aarch64-linux.pi4-installer" "sd-image" )

# Edit the wifi password to be embedded in the SD image
bootstrap-edit-wifi:
    #!/usr/bin/env sh
    set -e
    cd org-config
    agenix -e ./wifi/psk.age

# Call for a rebuild of the current system
rebuild *args:
    #!/usr/bin/env sh
    OS={{os()}}
    if [ $OS == linux ]; then 
        # TODO not tested yet
        nixos-rebuild --flake .#{{args}}
    elif [ $OS == macos ]; then
        darwin-rebuild --flake . {{args}}
    else
        echo "Unsupported operating system: $OS"
    fi

# Upgrade Nix in the current system
nix-upgrade:
    #!/usr/bin/env sh
    set -e
    sudo nix-channel --update
    OS={{os()}}
    if [ $OS == linux ]; then 
        sudo nix-env --install --attr nixpkgs.nix nixpkgs.cacert
        sudo systemctl daemon-reload
        sudo systemctl restart nix-daemon
    elif [ $OS == macos ]; then
        sudo nix-env --install --attr nixpkgs.nix
        sudo launchctl remove org.nixos.nix-daemon
        sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    fi

# Update the list of the wifi networks from the wifi secrets
wifi-update: secrets-update
    #!/usr/bin/env sh
    set -e
    cd org-config
    agenix -d ./wifi/psk.age | awk -F= '{print $1}' | jq -nR '[inputs]' > ./wifi/list.json
    echo "Updated org-config/wifi/list.json"                              

_pre-wifi-edit:
    #!/usr/bin/env sh
    set -e
    cd org-config
    agenix -e ./wifi/psk.age

# Edit the wifi networks available in NixOS
wifi-edit: _pre-wifi-edit wifi-update

# Update the password of the current user, or of the user specified as argument
password-change user="":
    #!/usr/bin/env sh
    _USR="{{user}}"
    [ -n "$_USR" ] || _USR=$(whoami)
    echo "Changing the password of: $_USR"
    read -s -p "Current password: " CURRENT_PASSWORD
    echo
    cd org-config
    CURRENT_SALT=$(agenix -d ./users/$_USR.hash.age | awk '{split($0,a,"$"); print a[3]}')
    if [ "$(mkpasswd -m sha-512 $CURRENT_PASSWORD $CURRENT_SALT)" != "$(agenix -d ./users/$_USR.hash.age)" ]; then
        echo "Warning: the current password is incorrect."
    fi
    read -s -p "New password: " NEW_PASSWORD 
    echo
    if [ "$(mkpasswd -m sha-512 $NEW_PASSWORD $CURRENT_SALT)" == "$(agenix -d ./users/$_USR.hash.age)" ]; then
        echo "The password is the same as the current one. Aborting."
        exit 0
    fi
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' EXIT
    mkpasswd -m sha-512 $NEW_PASSWORD > $tmpfile
    EDITOR="cp $tmpfile" agenix -e ./users/$_USR.hash.age 
    echo "Password changed. Don't forget to commit the changes and to rebuild the systems."

# Rekey the agenix secrets
secrets-update:
    #!/usr/bin/env sh
    set -e
    cd org-config
    agenix -r

# Update the public key and ip of a host, reload the config, and rekey the secrets
host-update-config ip hostname user="nixos":
    #!/usr/bin/env sh
    set -e
    JSON_FILE=org-config/hosts/linux/{{hostname}}.json
    # if [ -f "org-config/hosts/linux/{{hostname}}.nix" ]; then
    #     echo "The host already exists."
    #     exit 1
    # fi
    # Fetch the public key of the host using its ip, without checking the host key
    KEY=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{user}}@{{ip}} cat /etc/ssh/ssh_host_ed25519_key.pub)
    # Create an empty json file if it doesn't exist
    mkdir -p $(dirname $JSON_FILE)
    [ -f "$JSON_FILE" ] || echo "{}" > $JSON_FILE
    # Append the public key and the ip to the json file
    cat <<< $(jq --arg publicKey "$KEY" --arg ip {{ip}} '. + $ARGS.named' $JSON_FILE) > $JSON_FILE
    # Required to update the secrets & rebuild: non staged files are not taken into account
    git add $JSON_FILE
    # Rekey the secrets
    just secrets-update
    # Rebuild the system so to use ssh user@hostname instead of user@ip with the right public key
    just rebuild switch

# Generate the nix configuration from the right template
@host-template hostname:
    copier --vcs-ref HEAD --data hostname={{hostname}} --quiet --overwrite copy templates/host org-config/hosts/linux

# Create a new host in the config from an existing running machine
host-create ip hostname user="nixos": (host-update-config ip hostname user) (host-template hostname) 

# TODO
host-install:
    @echo "push config to the target, and build the system"
    exit 1

# Clean the entire nix store
@nix-clean:
    # ? Clean the builder as well? sudo ssh builder@linux-builder -i /etc/nix/builder_ed25519
    nix-collect-garbage
    nix-store --verify --check-contents --repair
    # TODO also clear the builder through sudo ssh builder@linux-builder -i /etc/nix/builder_ed25519

# Start a nix repl of the entire flake
@nix-repl:
    nix run .#repl
    
# Generate the documentation of the configuration options
@docgen:
    nix run .#docgen

