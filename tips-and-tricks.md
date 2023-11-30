## Show the colors palette
```sh
for i in {0..255}; do print -Pn “%K{$i} %k%F{$i}${(l:3::0:)i}%f “ ${${(M)$((i%6)):#3}:+$’\n’}; done
```

## Nix & NixOS

### Why a derivations is used?

https://github.com/utdemir/nix-tree
```sh
nix-store --query --referrers-closure /nix/store/w5lqp055w04k3z4x7zk6570bx267w3h3-bash-5.1-p12.drv
```
See: https://discourse.nixos.org/t/how-to-find-all-reverse-transitive-dependencies-of-a-package/18407/6