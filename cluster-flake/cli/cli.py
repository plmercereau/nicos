#! /usr/bin/env python
from lib.sd_image import build_sd_image
from lib.deploy import deploy
from lib.create import create
from lib.secrets import Secrets

import fire

class CLI(object):
    def __init__(self):
        self.secrets = Secrets()

    def deploy(self, machines = [], all=False):
        """Deploy one or several existing machines"""
        deploy(machines, all)
    
    def create(self, rekey=True):
        """Create a new machine in the cluster"""
        create(rekey)
    
    def build(self):
        """Build a machine ISO image"""
        build_sd_image()
        # TODO build a live CD image
        # TODO install a machine from the live CD image: 
        # * 1. boot from the live CD image
        # * 2. run the deploy command + copy the ssh private key using nixos-anywhere
    
if __name__ == '__main__':
  fire.Fire(CLI)
