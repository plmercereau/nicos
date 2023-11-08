#!/usr/bin/env nu
def main [_user?: string ] {

    let $user = $_user | default $env.USER
    print $"Changing password of ($user)"

    # Check current password
    # TODO: don't check if the user password file doesn't exist yet
    let $currentHash = (agenix -d $"./users/($user).hash.age")
    if ($currentHash != (openssl passwd -6 -salt ($currentHash | split column '$' | get column3 | first) (input -s "Current password: "))) {
        print "Wrong password"
        exit
    }
    echo
    
    # Prompt for a new password
    let $newPassword = input -s "New password: " 
    echo
    let $newPasswordConfirm = input -s "Confirm new password: " 
    echo
    if ($newPassword != $newPasswordConfirm) {
        print "Passwords do not match"
        exit
    }

    # Save the new password hash into a temporary file (agenix doesn't support stdin)
    let $tmp = mktemp
    openssl passwd -6 $newPassword | save -f $tmp
 
    # Update the user password file
    $env.EDITOR = $"cp ($tmp)"
    let $result = do {agenix -e $"./users/($user).hash.age"} | complete
    rm $tmp
    if ($result.exit_code != 0) {
        print "Error: ($result.stderr)"
        exit 
    }

    print "Password changed. Don't forget to commit the changes and to rebuild the systems."
}