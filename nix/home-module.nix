{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hakuspace;
  share = "${cfg.package}/share/hakuspace";

  /*
    DIRECTORIES THE SCRIPTS WRITE INTO, and therefore the ones that must stay
    real directories rather than becoming symlinks to the store.

    This is the whole reason the module links config entries INDIVIDUALLY
    instead of doing the obvious `xdg.configFile."waybar".source = ...`:

      waybar_manager.sh:39   ln -sf "$target_dir/config"    "$WAYBAR_DIR/config"
      waybar_manager.sh:40   ln -sf "$target_dir/style.css" "$WAYBAR_DIR/style.css"
      rofi_theme_switcher.sh:35
                             ln -sf "$USER_THEME_DIR/$t.rasi" "$CONFIG_DIR/$t.rasi"

    Point ~/.config/waybar at a store path and layout switching fails with
    "Read-only file system" -- the layouts are still there, but the switcher
    can never select one. Linking the children leaves the parent a writable
    directory that home-manager created, which is what those `ln -sf` calls
    need.

    Everything else is linked whole, because nothing writes into it: generated
    theme output goes to ~/.local/state/haku_theme and user overrides to
    ~/hakuspace-control, both outside ~/.config by design.
  */
  writableDirs = [ "waybar" "rofi" ];

  # From passthru, never readDir on the package: see the note beside it in
  # ./package.nix for why enumerating $out would make evaluation build.
  inherit (cfg.package.passthru) configChildren scriptNames;

  linkChildren = name: lib.listToAttrs (
    map (child: {
      name = "${name}/${child}";
      value.source = "${share}/config/${name}/${child}";
    }) configChildren.${name}
  );

  linkWhole = name: { ${name}.source = "${share}/config/${name}"; };

  selected = lib.filter (n: builtins.elem n cfg.configNames) cfg.package.passthru.configNames;
in
{
  options.programs.hakuspace = {
    enable = lib.mkEnableOption "the Hakuspace desktop (Waybar, Rofi, SwayNC and its script suite)";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The hakuspace package, as built by ./package.nix.";
    };

    compositor = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "hyprland" "niri" "mango" "labwc" ]);
      default = null;
      description = ''
        Which window-manager config under src/wm to install, or null to install
        none.

        NULL IS A REAL CHOICE, not a placeholder. A configuration that already
        manages its own compositor wants Hakuspace's bar, launcher and scripts
        WITHOUT a second, complete compositor config competing for the same
        file -- so the bar half and the window-manager half are separable.
      '';
    };

    configNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = cfg.package.passthru.configNames;
      defaultText = lib.literalExpression "every directory under src/common/config";
      example = [ "waybar" "rofi" "swaync" ];
      description = ''
        Which entries under src/common/config to manage in ~/.config.

        Narrow this where the host already owns a program: shipping the fish,
        kitty or starship configs on a machine that configures those elsewhere
        is a collision, and home-manager reports it as one rather than picking
        a winner.
      '';
    };

    controlDir = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Seed ~/hakuspace-control with the shipped defaults.

          COPIED, NOT SYMLINKED, and that is the point of the directory: it is
          where a user's own overrides live, so it has to be writable and has
          to survive a rebuild that changes the package. Existing files are
          never overwritten -- the same rule install.sh applies.
        '';
      };
    };

    extraScriptPath = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.playerctl ]";
      description = ''
        Extra packages on the scripts' PATH, for anything the wrapper in
        ./package.nix does not already carry.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ] ++ cfg.extraScriptPath;

    /*
      Scripts at ~/.local/bin, where the configs and keybinds expect them.

      The wrapped copies from the package, not the raw sources: the wrapper is
      what puts rofi, cava, jq, hyprctl and the colorthief-capable python3 on
      PATH, so a script works the same whether it was launched from a keybind,
      from Waybar's on-click, or from a terminal with nothing installed.
    */
    home.file = lib.mkMerge [
      (lib.listToAttrs (map (name: {
        name = ".local/bin/${name}";
        value.source = "${cfg.package}/bin/${name}";
      }) scriptNames))

      (lib.mkIf (cfg.compositor != null) {
        # Whole-tree link: nothing writes into the WM config, and the custom
        # entry point is ~/hakuspace-control/<wm>-custom.* which lives outside.
        ".config/${if cfg.compositor == "hyprland" then "hypr" else cfg.compositor}".source =
          "${share}/wm/${cfg.compositor}";
      })
    ];

    xdg.configFile = lib.mkMerge (
      map (n: if builtins.elem n writableDirs then linkChildren n else linkWhole n) selected
    );

    /*
      The control directory, copied on activation.

      writeBoundary first because this runs cp against $HOME: home-manager
      requires anything touching the real home to be ordered after the point
      where it has finished deciding what the generation contains.
    */
    home.activation.hakuspaceControl = lib.mkIf cfg.controlDir.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        control="$HOME/hakuspace-control"
        run mkdir -p "$control/waybar" "$control/rofi"
        for f in ${share}/control/*; do
          name="$(basename "$f")"
          if [ ! -e "$control/$name" ]; then
            run cp -r "$f" "$control/$name"
            run chmod -R u+w "$control/$name"
          fi
        done
      ''
    );
  };
}
