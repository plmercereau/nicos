import ipaddress
import questionary


class IpValidator(questionary.Validator):
    def validate(self, document):
        try:
            ipaddress.IPv4Address(document.text)
        except:
            raise questionary.ValidationError(
                message=f"Invalid IP address: {document.text}"
            )
