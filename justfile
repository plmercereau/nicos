@_default:
    just --list

currentUser := `whoami`

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
    if [ {{os()}} == linux ]; then 
        nixos-rebuild --flake . {{args}}
    elif [ {{os()}} == macos ]; then
        darwin-rebuild --flake . {{args}}
    else
        echo "Unsupported operating system: $OS"
    fi

# Upgrade Nix in the current system
nix-upgrade:
    #!/usr/bin/env sh
    set -e
    sudo nix-channel --update
    if [ {{os()}} == linux ]; then 
        sudo nix-env --install --attr nixpkgs.nix nixpkgs.cacert
        sudo systemctl daemon-reload
        sudo systemctl restart nix-daemon
    elif [ {{os()}} == macos ]; then
        sudo nix-env --install --attr nixpkgs.nix
        sudo launchctl remove org.nixos.nix-daemon
        sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    fi

# Update the list of the wifi networks from the wifi secrets
@wifi-update: secrets-update
    cd org-config && agenix -d ./wifi/psk.age | awk -F= '{print $1}' | jq -nR '[inputs]' > ./wifi/list.json
    echo "Updated org-config/wifi/list.json"                              

# Edit the wifi networks available in NixOS
@wifi-edit:
    cd org-config && agenix -e ./wifi/psk.age
    just wifi-update

# Update the password of the current user, or of the user specified as argument
password-change user=currentUser:
    #!/usr/bin/env sh
    echo "Changing the password of: {{user}}"
    read -s -p "Current password: " CURRENT_PASSWORD
    echo
    cd org-config
    CURRENT_SALT=$(agenix -d ./users/{{user}}.hash.age | awk '{split($0,a,"$"); print a[3]}')
    if [ "$(mkpasswd -m sha-512 $CURRENT_PASSWORD $CURRENT_SALT)" != "$(agenix -d ./users/{{user}}.hash.age)" ]; then
        echo "Warning: the current password is incorrect."
    fi
    read -s -p "New password: " NEW_PASSWORD 
    echo
    if [ "$(mkpasswd -m sha-512 $NEW_PASSWORD $CURRENT_SALT)" == "$(agenix -d ./users/{{user}}.hash.age)" ]; then
        echo "The password is the same as the current one. Aborting."
        exit 0
    fi
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' EXIT
    mkpasswd -m sha-512 $NEW_PASSWORD > $tmpfile
    EDITOR="cp $tmpfile" agenix -e ./users/{{user}}.hash.age 
    echo "Password changed. Don't forget to commit the changes and to rebuild the systems."

# Rekey the agenix secrets
@secrets-update:
    cd org-config && agenix -r

# Update the public key and ip of a host, reload the config, and rekey the secrets
host-create-config-json ip hostname user="nixos":
    #!/usr/bin/env sh
    set -e
    # if [ -f "org-config/hosts/linux/{{hostname}}.nix" ]; then
    #     echo "The host already exists."
    #     exit 1
    # fi
    # Fetch the public key of the host using its ip, without checking the host key
    KEY=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{user}}@{{ip}} cat /etc/ssh/ssh_host_ed25519_key.pub)
    # TODO remove --vcs-ref HEAD 
    # TODO copier update
    copier copy --vcs-ref HEAD --data hostname="{{hostname}}" --data publicKey="$KEY" --data ip="{{ip}}" --quiet --overwrite templates/host-json org-config/hosts/linux
    # Required to update the secrets & rebuild: non staged files are not taken into account
    git add org-config/hosts/linux/{{hostname}}.json
    # Rekey the secrets
    just secrets-update
    # Rebuild the system so to use ssh user@hostname instead of user@ip with the right public key
    # TODO overkill?: only load the new SSH host alias in the current nix environment
    just rebuild switch

# Generate the nix configuration from the right template
@host-create-config-nix hostname:
    # TODO remove --vcs-ref HEAD 
    # TODO copier update
    copier copy --vcs-ref HEAD --data hostname={{hostname}} --quiet --overwrite templates/host-nix org-config/hosts/linux
    git add org-config/hosts/linux/{{hostname}}.nix

# Create a new host in the config from an existing running machine
host-create ip hostname user="nixos": (host-create-config-json ip hostname user) (host-create-config-nix hostname) (host-deploy hostname user "false")

# Deploy system configuration to a given host
@host-deploy hostname user=currentUser magic-rollback="true":
    nix run github:serokell/deploy-rs .#{{hostname}} -- --ssh-user {{user}} --magic-rollback {{magic-rollback}} --interactive

# Clean the entire nix store
@nix-clean:
    # ? Clean the builder as well? sudo ssh builder@linux-builder -i /etc/nix/builder_ed25519
    nix-collect-garbage
    nix-store --verify --check-contents --repair

# Start a nix repl of the entire flake
@nix-repl:
    nix run .#repl
    
# Generate the documentation of the configuration options
@docgen:
    nix run .#docgen

