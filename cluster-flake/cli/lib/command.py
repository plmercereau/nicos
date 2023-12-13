import subprocess

def run_command(command):
    output = subprocess.run(command, shell=True, stdout=subprocess.PIPE,text=True)
    if output.returncode != 0:
        exit(1)
    return output.stdout.strip()
