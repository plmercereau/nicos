{hardware, ...}: {
  {% if hardware %}imports = [hardware.{{hardware}}];{% endif %}
  settings = {
    id = {{id}};
    sshPublicKey = "{{ ssh_public_key }}";
    networking = {
      {% if public_ip %}publicIP = "{{ public_ip }}";{% endif %}
      {% if local_ip %}localIP = "{{ local_ip }}";{% endif %}
      vpn = {
        enable = true;
        publicKey = "{{ wg_public_key }}";
        # TODO bastion feature
      };
    }
  };
}
