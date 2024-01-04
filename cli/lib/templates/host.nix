{hardware, ...}: {
  {% if hardware %}imports = [hardware.{{hardware}}];{% endif %}
  settings = {
    sshPublicKey = "{{ ssh_public_key }}";
    networking = {
      {%- if public_ip %}
      publicIP = "{{ public_ip }}";{% endif %}
      {%- if local_ip %}
      localIP = "{{ local_ip }}";{% endif %}
      vpn = {
        enable = true;
        id = {{id}};
        publicKey = "{{ wg_public_key }}";
      };
    };
  };
}
