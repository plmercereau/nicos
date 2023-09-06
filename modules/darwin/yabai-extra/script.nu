#!/usr/bin/env nu
let log_file = "/tmp/yabai-extra.log"
touch $log_file

def log [message: string] {
    echo $"\n($message)" | save $log_file --append
}

def main [
    action: string
] {
    # TODO add action "when space moves"
    if ($action == "push") {
        log "push"
        yabai -m query --windows | from json | where app in ["Mail","Calendar"] | get id | each {|id| yabai -m window $id --display 2}
        yabai -m query --windows | from json | where app in ["Mail"] | get id | each {|id| yabai -m window $id --warp west}
        yabai -m query --windows | from json | where app in ["Calendar"] | get id | each {|id| yabai -m window $id --warp east}        
        log "pushed"
    } else if ($action == "pull") {
        log "pull"
        yabai -m query --windows | from json | where app in ["Mail","Calendar"] | get id | each {|id| yabai -m window $id --display 1 --space last}
        yabai -m query --windows | from json | where app in ["Mail"] | get id | each {|id| yabai -m window $id --warp west}
        yabai -m query --windows | from json | where app in ["Calendar"] | get id | each {|id| yabai -m window $id --warp east}        
        log pulled
    } else {
        log $"invalid option: ($action)" 
    }
    
}
