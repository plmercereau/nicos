@_default:
    just --list

@_set-user user: 
    USER="{{user}}"
    [ -n "$USER" ] || USER=$(whoami)

# Run a nix build command and link the result from <subpath>/* to ./output/
@nix-build target subpath=".":
    #!/usr/bin/env sh
    set -e
    # TODO the --impure flag should be removed once we don't load the wifi secret when bootstraping sd-images anymore
    RESULT=$(nix build {{target}} --no-link --print-out-paths --impure)/{{subpath}}
    mkdir -p ./output
    ln -sf $RESULT/* ./output/
    echo "Result: ./output/$(ls $RESULT)"

# Build a Raspberry Pi Zero 2w SD image using Docker
@bootstrap-build-zero2: (nix-build ".#packages.aarch64-linux.zero2-installer" "sd-image" )

# Build a Raspberry Pi 4 SD image using Docker
@bootstrap-build-pi4: (nix-build ".#packages.aarch64-linux.pi4-installer" "sd-image" )

# Edit the wifi password to be embedded in the SD image
@bootstrap-edit-wifi:
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
@wifi-edit: _pre-wifi-edit wifi-update

# Update the password of the current user, or of the user specified as argument
password-change user="": (_set-user user)
    #!/usr/bin/env sh
    echo "Changing the password of: $USER"
    read -s -p "Current password: " CURRENT_PASSWORD
    echo
    cd org-config
    CURRENT_SALT=$(agenix -d ./users/$USER.hash.age | awk '{split($0,a,"$"); print a[3]}')
    if [ "$(mkpasswd -m sha-512 $CURRENT_PASSWORD $CURRENT_SALT)" != "$(agenix -d ./users/$USER.hash.age)" ]; then
        echo "Warning: the current password is incorrect."
    fi
    read -s -p "New password: " NEW_PASSWORD 
    echo
    if [ "$(mkpasswd -m sha-512 $NEW_PASSWORD $CURRENT_SALT)" == "$(agenix -d ./users/$USER.hash.age)" ]; then
        echo "The password is the same as the current one. Aborting."
        exit 0
    fi
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' EXIT
    mkpasswd -m sha-512 $NEW_PASSWORD > $tmpfile
    EDITOR="cp $tmpfile" agenix -e ./users/$USER.hash.age 
    echo "Password changed. Don't forget to commit the changes and to rebuild the systems."

# Rekey the agenix secrets
secrets-update:
    #!/usr/bin/env sh
    set -e
    cd org-config
    agenix -r

@_pre-host-update-public-key hostname user="nixos":
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{user}}@{{hostname}}:/etc/ssh/ssh_host_ed25519_key.pub org-config/hosts/linux/{{hostname}}.key

# Update the public key of a host, and rekey the secrets
@host-update-public-key hostname user="nixos": (_pre-host-update-public-key hostname user) secrets-update

# Generate the nix configuration from the right template
@host-template hostname:
    copier --vcs-ref HEAD  --data hostname={{hostname}} --quiet copy templates/host org-config/hosts

# TODO set hostname-ip in /etc/hosts or in the ssh config (+ system switch) + git add
# Add a new host alias in the ssh config from an IP address
host-add-ssh ip hostname:
    #!/usr/bin/env sh
    set -e
    echo "TODO"
    exit 1
    # 1. ping
    # 2. add org-config/hosts/linux/hostname.ips.json: { "local": "ip" }
    # 3. git add
    # 4. rebuild

# Create a new host in the config from an existing running machine
@host-create ip hostname user="nixos": (host-add-ssh ip hostname) (host-template hostname) (host-update-public-key hostname user)

# Recreate the host nix configuration and public key
@host-recreate hostname user="": (_set-user user) (host-template hostname) (host-update-public-key hostname user) 

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

