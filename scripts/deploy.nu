#!/usr/bin/env nu
def main [..._targets: string ] {
    let $hosts = ls hosts/*.toml | get name | path basename | str replace ".toml" ""
    let $targets = if ($_targets|length) == 0 {$hosts | input list --multi} else {$_targets}
    if ( $targets|length ) > 0 {
        nix run github:serokell/deploy-rs -- --magic-rollback false --targets ( $targets | each {|x| $".#($x)"} | str join " ")
    }
}