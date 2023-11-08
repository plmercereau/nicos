#!/usr/bin/env nu
def main [..._targets: string ] {
    let $hosts = ls hosts/*.json | get name | path basename | str replace ".json" ""
    let $hostname = hostname
    let $targets = if ($_targets|length) == 0 {$hosts | input list --multi} else {$_targets}
    if ($hostname in $targets) {
        if (uname) == "Darwin" {
            darwin-rebuild --flake . switch
        } else {
            nixos-rebuild --flake . switch
        }
    }
    let $remote = $targets | filter {|x| $x != $hostname}
    if ($remote|length) > 0 {
        nix run github:serokell/deploy-rs -- --targets ($remote | each {|x| $".#($x)"} | str join " ")
    }
}