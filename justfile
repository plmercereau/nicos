@_default:
    just --list

currentUser := `whoami`

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
    agenix -d ./wifi/psk.age | awk -F= '{print $1}' | jq -nR '[inputs]' > ./wifi/list.json
    echo "Updated wifi/list.json"                              

# Edit the wifi networks available in NixOS
@wifi-edit:
    agenix -e ./wifi/psk.age
    # TODO skip if no change
    just wifi-update

# Update the password of the current user, or of the user specified as argument
password-change user=currentUser:
    #!/usr/bin/env sh
    echo "Changing the password of: {{user}}"
    read -s -p "Current password: " CURRENT_PASSWORD
    echo
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
    agenix -r

# Generate the nix configuration from the right template
@host-create-config-nix hostname:
    # TODO remove --vcs-ref HEAD 
    # TODO copier update
    copier copy --vcs-ref HEAD --data hostname={{hostname}} --quiet --overwrite templates/host-nix hosts
    git add hosts/{{hostname}}.nix

# Create a new host in the config from an existing running machine
# host-create ip hostname user="nixos": (host-create-config-nix hostname) (host-deploy hostname user "false")

# Deploy system configuration to a given host
@host-deploy hostname *FLAGS:
    # TODO if FLAGS is used to specify other targets, then add a .# prefix for each of them
    nix run github:serokell/deploy-rs -- --targets .#{{hostname}} {{FLAGS}}

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

