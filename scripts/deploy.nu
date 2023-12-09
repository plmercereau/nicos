#!/usr/bin/env nu
def main [..._machines: string ] {
    let $available = ls hosts*/*.nix | get name | path basename | str replace ".nix" ""
    let $machines = if ( $_machines | length ) == 0 {$available | input list --multi } else {$_machines}
    if ( $machines | length ) > 0 {
        let $targets = $machines | each {|x| $".#($x)"}
        run-external "nix" "run" "github:serokell/deploy-rs" "--" "--magic-rollback" "false" "--targets" $targets
    } else {
        echo "No machines specified"
        exit 1
    }
}