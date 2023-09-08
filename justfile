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
build-image-zero2: (nix-build ".#packages.aarch64-linux.zero2-installer" "sd-image" )

# Build a Raspberry Pi 4 SD image using Docker
build-image-pi4: (nix-build ".#packages.aarch64-linux.pi4-installer" "sd-image" )

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
wifi-update:
    #!/usr/bin/env sh
    set -e
    cd org-config
    agenix -d ./wifi/psk.age | awk -F= '{print $1}' | jq -nR '[inputs]' > ./wifi/list.json
    echo "Updated org-config/wifi/list.json"                              

_wifi-edit-secrets:
    #!/usr/bin/env sh
    set -e
    cd org-config
    agenix -e ./wifi/psk.age
    cd ..

# Edit the wifi networks available in NixOS
wifi-edit: _wifi-edit-secrets wifi-update

# Update the password of the current user, or of the user specified as argument
password-change  user="":
    #!/usr/bin/env sh
    set -e
    USER="{{user}}"
    [ -n "$USER" ] || USER=$(whoami)
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
    cd ..

# Clean the entire nix store
nix-clean:
    # ? Clean the builder as well? sudo ssh builder@linux-builder -i /etc/nix/builder_ed25519
    nix-collect-garbage
    nix-store --verify --check-contents --repair

# Start a nix repl of the entire flake
nix-repl:
    nix run .#repl
    
# Generate the documentation of the configuration options
docgen:
    nix run .#docgen

