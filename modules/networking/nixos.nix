{config, ...}: {
  #! From svros: https://github.com/search?q=repo%3Anix-community%2Fsrvos%20NetworkManager-wait-online&type=code
  # The notion of "online" is a broken concept
  # https://github.com/systemd/systemd/blob/e1b45a756f71deac8c1aa9a008bd0dab47f64777/NEWS#L13
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.network.wait-online.enable = false;
  # ? Not 100% sure this is a good idea
  networking.domain = config.settings.networking.localDomain;
}
