export def input_required [
    prompt?: string, 
    --suppress-output(-s): bool = false] {
    input_rule {|x| not ($x |is-empty)} $prompt "Value is required" --suppress-output $suppress_output
}

def is-ip [] {
    each { |it| $it =~ '^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$' }
}

export def input_ip [
    prompt?: string = "IP address", 
    --required: bool = false
] {
    let $rule = {|x| if ((not $required) and ($x |is-empty)) {true} else {$x | is-ip}}
    input_rule $rule $prompt "Invalid IP address"
}

export def input_rule [
    rule: closure,
    prompt?: string, 
    message?: string = "Invalid value",
    --suppress-output(-s): bool = false] {
    loop {
        let $result = if $suppress_output {input $prompt  --suppress-output} else {input $prompt}
        if (do $rule $result) {
            return (if ($result | is-empty) {null} else {$result})
        } else {
            print $message
        }
    }
}

export def save_secret [path: string, contents: string] {
    let $temp_file = (mktemp)
    $contents | save --force $temp_file
    $env.EDITOR = $"cp ($temp_file)"
    let $result = do { agenix --edit $path } | complete
    rm $temp_file
    if ($result.exit_code != 0) {
        print $"Error: ($result.stderr)"
        exit 1
    }
}

# * Generate ed25519 private/public keys into a temporary directory
export def generate_ssh_keys [
    host: string,
    private_key: string # path of the private key file
] {
    let $public_key = if ($private_key | path exists) { ssh-keygen -f $private_key -y | str trim} else {
        ssh-keygen -t ed25519 -N '' -C '' -f $private_key | str join
        let $result = (open $"($private_key).pub" --raw | str trim)
        rm $"($private_key).pub"
        $result
    }

    # * Update the public key in the machine config if it has changed, and rekey the secrets if needed
    let $host_config = $"hosts/($host).toml"
    touch $host_config
    let $config = (open $host_config)
    if ("sshPublicKey" in $config and ($config | get sshPublicKey ) == $"($public_key)")) {
        # No need to update the ssh public key
        return
    }
    # * Add the public key to the machine config
    open $"hosts/($host).toml" | upsert sshPublicKey $public_key | save --force $"hosts/($host).toml"

    # * Rekey the Agenix secrets
    let $result = do { agenix --rekey } | complete
    if ($result.exit_code != 0) {
        print $"Error: ($result.stderr)"
        exit 1
    }    
}