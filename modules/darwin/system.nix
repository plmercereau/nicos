{
  config,
  pkgs,
  lib,
  ...
}:
with lib; {
  services.nix-daemon.enable = true; # Make sure the nix daemon always runs
  nix.package = pkgs.nixVersions.stable;
  nix.settings = {
    cores = 0; # use all cores
    max-jobs = 10; # use all cores (M1 has 8, M2 has 10)
    trusted-users = ["@admin"];
    extra-experimental-features = ["nix-command" "flakes"];
    keep-outputs = true;
    keep-derivations = true;
  };

  nix.configureBuildUsers = true; # Allow nix-darwin to build users

  # Create a Linux remote builder that works out of the box
  nix.linux-builder = {
    enable = true;
    maxJobs = 10; # use all cores (M1 has 8, M2 has 10)
  };

  homebrew = {
    enable = true;
    global.brewfile = true;
    # updates homebrew packages on activation,
    # can make darwin-rebuild much slower (otherwise i'd forget to do it ever though)
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    # Raycast is a replacement of Spotlight that manages the launch of apps installed with nix
    casks = ["raycast"];
  };

  # Apply settings on activation.
  # * See https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
  # TODO restart yabai/skhd (probably not working because of killall Dock)
  system.activationScripts.postUserActivation.text = ''
    # Following line should allow us to avoid a logout/login cycle
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    killall Dock
    osascript -e 'display notification "Nix settings applied"'
  '';

  # * See: https://github.com/LnL7/nix-darwin/blob/master/tests/system-defaults-write.nix
  system.defaults = {
    loginwindow.GuestEnabled = false;
  };

  system.defaults.CustomUserPreferences = {
    # * See https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = true;
      ShowMountedServersOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      _FXSortFoldersFirst = true;
      # When performing a search, search the current folder by default
      FXDefaultSearchScope = "SCcf";
    };
    "com.apple.desktopservices" = {
      # Avoid creating .DS_Store files on network or USB volumes
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
    "com.apple.screensaver" = {
      # Require password immediately after sleep or screen saver begins
      askForPassword = 1;
      askForPasswordDelay = 0;
    };
    "com.apple.Safari" = {
      # Privacy: don’t send search queries to Apple
      UniversalSearchEnabled = false;
      SuppressSearchSuggestions = true;
      # Press Tab to highlight each item on a web page
      WebKitTabToLinksPreferenceKey = true;
      ShowFullURLInSmartSearchField = true;
      # Prevent Safari from opening ‘safe’ files automatically after downloading
      AutoOpenSafeDownloads = false;
      ShowFavoritesBar = false;
      IncludeInternalDebugMenu = true;
      IncludeDevelopMenu = true;
      WebKitDeveloperExtrasEnabledPreferenceKey = true;
      WebContinuousSpellCheckingEnabled = true;
      WebAutomaticSpellingCorrectionEnabled = false;
      # AutoFillFromAddressBook = false;
      # AutoFillCreditCardData = false;
      # AutoFillMiscellaneousForms = false;
      WarnAboutFraudulentWebsites = true;
      WebKitJavaEnabled = false;
      WebKitJavaScriptCanOpenWindowsAutomatically = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" = true;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled" = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles" = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically" = false;
    };
    "com.apple.mail" = {
      # Disable inline attachments (just show the icons)
      DisableInlineAttachmentViewing = true;
    };
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
    };
    "com.apple.print.PrintingPrefs" = {
      # Automatically quit printer app once the print jobs complete
      "Quit When Finished" = true;
    };
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      # Check for software updates daily, not just once per week
      ScheduleFrequency = 1;
      # Download newly available updates in background
      AutomaticDownload = 1;
      # Install System data files & security updates
      CriticalUpdateInstall = 1;
    };
    "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
    # Prevent Photos from opening automatically when devices are plugged in
    "com.apple.ImageCapture".disableHotPlug = true;
    # Turn on app auto-update
    "com.apple.commerce".AutoUpdate = true;
    # Disable Siri
    "com.apple.Siri" = {
      SiriPrefStashedStatusMenuVisible = 0;
      StatusMenuVisible = 0;
      VoiceTriggerUserEnabled = 0;
    };
    "com.grammarly.ProjectLlama" = {
      SUAutomaticallyUpdate = 0;
      SUEnableAutomaticChecks = 0;
    };
    "com.raycast.macos" = {
      initialSpotlightHotkey = "Command-49";
      raycastGlobalHotkey = "Command-49";
      onboardingCompleted = 1;
      developerFlags = 0;
      "permissions.folders.read:/Users/pilou/Desktop" = 1;
      "permissions.folders.read:/Users/pilou/Documents" = 1;
      "permissions.folders.read:/Users/pilou/Downloads" = 1;
      "permissions.folders.read:cloudStorage" = 1;
    };
    # ! disable spotlight shortcut(s) when using raycast
    # * See: https://github.com/LnL7/nix-darwin/pull/636
  };

  # Enable sudo authentication with Touch ID
  # See: https://daiderd.com/nix-darwin/manual/index.html#opt-security.pam.enableSudoTouchIdAuth
  security.pam.enableSudoTouchIdAuth = true;
}
