{hardware, ...}: {
  {% if hardware %}imports = [hardware.{{hardware}}];{% endif %}
  settings = {
    sshPublicKey = "{{ ssh_public_key }}";
    {%- if public_ip %}
    publicIP = "{{ public_ip }}";
    {%- endif %}
    {%- if local_ip %}
    localIP = "{{ local_ip }}";
    {%- endif %}
    {%- if "builder" in features %}
    nix-builder.enable = true;
    {%- endif %}
  };
  {%- if "wifi" in features %}
  networking.wireless.enable = true;
  {%- endif %}
}
