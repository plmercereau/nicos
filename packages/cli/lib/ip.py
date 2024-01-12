import ipaddress
from questionary import Validator, ValidationError


def validateIp(value, taken=[], optional=False):
    if optional and len(value) == 0:
        return True
    if len(value) == 0:
        return "Please enter a value"
    if value in taken:
        return "IP address already taken"
    try:
        ipaddress.IPv4Address(value)
    except:
        return "Invalid IP address"
    return True
