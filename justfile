@_default:
    just --list

# Run a nix build command and link the result from <subpath>/* to ./output/
nix-build target subpath=".":
    #!/usr/bin/env sh
    set -e
    # TODO the --impure flag should be removed once we don't load the wifi secret anymore
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

# ? Add the nix installer too?
# TODO linux script too
# Install the nix-darwin program
install-nix:
    nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer --out-file /tmp/result
    /tmp/result/bin/darwin-installer
    rm /tmp/result
    darwin-rebuild switch

# Upgrade Nix in the current system
upgrade-nix:
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
    cd org-config/secrets
    agenix -d wifi.age | awk -F= '{print $1}' | jq -nR '[inputs]' > ../wifi.json
    echo "Updated wifi.json"                              

# Edit the wifi networks
edit-wifi:
    #!/usr/bin/env sh
    set -e
    cd org-config/secrets
    agenix -e wifi.age
    cd ../..
    just wifi-update

clean:
    # ? Clean the builder as well? sudo ssh builder@linux-builder -i /etc/nix/builder_ed25519
    nix-collect-garbage
    nix-store --verify --check-contents --repair


docgen:
    nix run .#docgen

repl:
    nix run .#repl