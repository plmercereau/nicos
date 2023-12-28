#!/usr/bin/env python

from setuptools import setup, find_packages

setup(
    name="cli",
    version="1.0",
    # Modules to import from other scripts:
    packages=find_packages(),
    include_package_data=True,
    # Executables
    py_modules=["cli"],
    entry_points={
        "console_scripts": [
            "nicos = cli:main",
        ],
    },
)
