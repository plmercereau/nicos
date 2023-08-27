{ pkgs, lib, config, flakeInputs, ... }:
{
  settings.hardwarePlatform = config.settings.hardwarePlatforms.m1;

  # https://daiderd.com/nix-darwin/manual/index.html#opt-networking.localHostName
  # networking.localHostName = "Pilous-MacBook-Pro";

  # TODO move most of these packages in the "common" darwin packages
  homebrew.casks = [
    "adguard"
    "balenaetcher" # ? check if available in nix
    "battle-net"
    "bitwarden" # not available in darwin
    "docker" # ? may be a better way to install docker on darwin/nix
    "dropbox"
    "goldencheetah" # not available in darwin
    "google-chrome" # not available in darwin
    "grammarly"
    "grammarly-desktop"
    "microsoft-teams"
    "notion" # not available in darwin
    "onyx" # Mac cleaner
    "rectangle" # Move and resize windows in macOS using keyboard shortcuts or snap areas
    "skype"
    "skype-for-business"
    "sonos"
    "spotify"
    "utm"
    "webex"
    "whatsapp"
    "zoom"
    "zwift"
    # TODO check if the following are available in nix
    # "arduino"
    # "cyberghost-vpn"
    # "dbeaver-community"
    # "gimp"
    # "postman"
    # "signal"
    # "steam"
    # "thonny"
  ];
  # TODO remove this once the bluetooth installer package is developed
  age.secrets.wifi-install = {
    file = ../../secrets/wifi-install.age;
    path = "/run/agenix/wifi-install";
    group = "admin";
    mode = "740";
  };

  home-manager.users.pilou = {
    programs.vscode.enable = true;
    programs.helix.enable = true;

    programs.helix.defaultEditor = true;

    programs.alacritty.enable = true;

    programs.zsh.dirHashes = {
      config = "$HOME/dev/plmercereau/nix-config";
      desk = "$HOME/Desktop";
      dev = "$HOME/dev";
      dl = "$HOME/Downloads";
      docs = "$HOME/Documents";
      gh = "$HOME/dev/plmercereau";
      vids = "$HOME/Videos";
      ec = "$HOME/Documents/EC";
    };

    # * See: https://mipmip.github.io/home-manager-option-search/?query=programs.gh
    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };

    # * https://mipmip.github.io/home-manager-option-search/?query=home.file

    # ! does not build - tests are failing
    # programs.neomutt.enable = true;
    # TODO move most of these packages in the "common" darwin packages
    home.packages = with pkgs;
      [
        pstree # ps faux doesn't work on darwin
        # asciinema # Recording + sharing terminal sessions
        # navi # Interactive cheat sheet
        aria2 # better wget
        bandwhich # Bandwidth utilization monitor
        bitwarden-cli
        ctop # container metrics & monitoring
        deno
        diff-so-fancy # better diff # TODO nix options?
        discord
        dogdns # better dig
        duf # better df
        fd # alternative to find
        fdupes # Duplicate file finder
        fzf # better find # ? too heavy to put as a common package?
        glances # Resource monitor + web
        gping # interactive ping
        iina # TODO move back to brew...
        just
        lazydocker # Full Docker management app
        nmap
        qbittorrent
        tldr # complement to man
      ];
  };
}
