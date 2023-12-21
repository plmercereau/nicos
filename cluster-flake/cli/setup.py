#!/usr/bin/env python

from setuptools import setup, find_packages
from glob import glob
import os

setup(
    name="cli",
    version="1.0",
    # Modules to import from other scripts:
    packages=find_packages(),
    include_package_data=True,
    # Executables
    scripts=["cli.py"],
)
