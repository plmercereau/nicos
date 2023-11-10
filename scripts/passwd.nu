#!/usr/bin/env nu

use lib.nu [save_secret, input_required]

def main [user?: string ] {
    let $user = $user | default $env.USER

    # * Don't check password if the user password file doesn't exist yet
    if ( $"./users/($user).hash.age" | path exists) {
        print $"Changing password of '($user)'"
        # * Check current password
        let $current_hash = (agenix --decrypt $"./users/($user).hash.age")
        if ($current_hash != (openssl passwd -6 -salt ($current_hash | split column '$' | get column3 | first) (input_required "Current password: " --suppress-output=true ))) {
            print "Wrong password"
            exit
        }
        echo    
    } else {
        if (not ($"./users/($user).toml" | path exists)) {
            print $"User '($user)' does not exist"
            exit
        }
        print $"Creating a password for '($user)'"
    }
    
    # Prompt for a new password
    let $new_password = input_required "New password: " --suppress-output=true
    echo
    let $new_password_confirm = input_required "Confirm new password: " --suppress-output=true
    echo
    if ($new_password != $new_password_confirm) {
        print "Passwords do not match"
        exit
    }

    # Update the user password file
    save_secret $"./users/($user).hash.age" (openssl passwd -6 $new_password)

    print "Password changed. Don't forget to commit the changes and to rebuild the systems."
}