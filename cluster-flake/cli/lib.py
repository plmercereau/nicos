import sys
import subprocess

def run_command(command):
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        # Handle the error
        error_message = result.stderr
        print(f"Error running the command: {error_message}")
        sys.exit(1)
    return result.stdout.strip()
