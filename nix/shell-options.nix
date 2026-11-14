# The options both modules offer, so a user's profile and the system build the same package with the same defaults.
{ lib }:
{
  options = {
    installFont = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the typeface Atkinson Hyperlegible Next, which the shell, the lock screen and KWin's QML are set in, once the module is enabled. Turn it off when the configuration provides the typeface itself.";
    };

    background = lib.mkOption {
      type = lib.types.enum [
        "rekta"
        "solid"
      ];
      default = "rekta";
      description = "What each monitor shows behind the windows: \"rekta\" is the colour bg with a faint print of tiles in the bottom right corner, \"solid\" the colour bg alone. It takes effect with the default package once the module is enabled, as the default that a \"background\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };

    contrast = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "more"
          "normal"
        ]
      );
      default = null;
      description = "Rekta's more contrast: \"more\" takes the contrast colours (every text pair at 7:1, opaque glass) and frames each status tile, \"normal\" keeps the regular colours. Null follows the system's contrast preference where the platform reports one. It takes effect with the default package once the module is enabled, as the default that a \"contrast\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };

    density = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "comfortable"
          "compact"
        ]
      );
      default = null;
      description = "How much room the shell's controls take: \"comfortable\" (larger targets) or \"compact\". Null leaves it automatic: compact for a fine pointer. It takes effect with the default package once the module is enabled, as the default that a \"density\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };

    searchEscape = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "close"
          "back"
        ]
      );
      default = null;
      description = "What Escape does in the Start's search: \"close\" clears the search and closes the Start, \"back\" clears the search and goes back to the place before. Null leaves it at \"close\". It takes effect with the default package once the module is enabled, as the default that a \"searchEscape\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };

    showRecent = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Whether the Start shows \"zuletzt\", the files used last, as KDE's activity manager keeps them. False hides the section, and the shell then reads nothing of what was opened. Null leaves it shown. It takes effect with the default package once the module is enabled, as the default that a \"showRecent\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };
  };

  # Options that are gone; setting one stops the build with a word on why.
  removed = [
    (lib.mkRemovedOptionModule [
      "programs"
      "rekta-shell"
      "startTempo"
    ] "The Start always turns at Rekta's pace for a called place; there is no setting.")
  ];

  # The settings a module's options hand to the package as its defaults; unset ones stay out.
  defaultsOf =
    cfg:
    {
      inherit (cfg) background;
    }
    // lib.filterAttrs (_: value: value != null) {
      inherit (cfg)
        contrast
        density
        searchEscape
        showRecent
        ;
    };
}
