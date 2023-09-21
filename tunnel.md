### multiple bastions: https://unix.stackexchange.com/questions/720952/is-there-a-possibility-to-add-alternative-jump-servers-in-ssh-config
### Reverse tunnel: ssh -N -R 9000:localhost:22 tunneller@bastion
### Host to jump to via jumphost1.example.org
Host behindbastion
  HostName localhost
  Port 9000
  ProxyJump tunneller@bastion
