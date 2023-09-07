## Add a new host

### 1. copy the public host key from the new machine into org-config/hosts/

scp machine:/etc/ssh/ssh_host_ed25519_key.pub org-config/hosts/linux/hostname.key
git add the file

### 2. rekey secrets

cd org-config && agenix -r

### 3. create a org-config/hosts/linux/newhost.nix file

Ideally, automate the process with `nixos-generate-config`, or dedicated pi4/zero2 scripts.
ssh newhost nixos-generate-config --show-hardware-config

### 4. push changes to git

### 5. pull git in the new machine to /etc/nixos

### 6. switch to the new configuration

nixos-rebuild switch --flake .#hostname
