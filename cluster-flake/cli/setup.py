#!/usr/bin/env python

from setuptools import setup, find_packages
from glob import glob
import os 

setup(name='cli',
      version='1.0',
      # Modules to import from other scripts:
      packages=find_packages(),
      py_modules=['run', 'agenix', 'config'],
      data_files=[('templates', glob(os.path.join('templates', '*')))],
      # Executables
      scripts=["cli.py"],
     )
