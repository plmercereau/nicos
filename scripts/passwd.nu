#!/usr/bin/env nu

use lib.nu [save_secret, input_required]

def main [_user?: string ] {

    let $user = $_user | default $env.USER
    print $"Changing password of ($user)"

    # Check current password
    # TODO: don't check if the user password file doesn't exist yet
    let $currentHash = (agenix --decrypt $"./users/($user).hash.age")
    if ($currentHash != (openssl passwd -6 -salt ($currentHash | split column '$' | get column3 | first) (input_required "Current password: " --suppress-output=true ))) {
        print "Wrong password"
        exit
    }
    echo
    
    # Prompt for a new password
    let $newPassword = input_required "New password: " --suppress-output=true
    echo
    let $newPasswordConfirm = input_required "Confirm new password: " --suppress-output=true
    echo
    if ($newPassword != $newPasswordConfirm) {
        print "Passwords do not match"
        exit
    }

    # Update the user password file
    save_secret $"./users/($user).hash.age" (openssl passwd -6 $newPassword)

    print "Password changed. Don't forget to commit the changes and to rebuild the systems."
}