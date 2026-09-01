{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  # runtime, derived from what src/common/local/bin actually calls
  bash,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  procps,
  jq,
  libnotify,
  rofi,
  waybar,
  swaynotificationcenter,
  cava,
  cliphist,
  wl-clipboard,
  grim,
  slurp,
  imagemagick,
  wlr-randr,
  brightnessctl,
  pulseaudio,
  glib,
  xdg-utils,
  # optional -- null to leave the feature to fail gracefully at runtime
  thunar ? null,
  hyprland ? null,
  hyprlock ? null,
  hypridle ? null,
  hyprpicker ? null,
  hyprsunset ? null,
  gammastep ? null,
  mpvpaper ? null,
  awww ? null,
  wl-screenrec ? null,
  kitty ? null,
}:

/*
  Hakuspace as a PACKAGE rather than a directory of files to copy.

  install.sh exists for distributions where that is the only option. On NixOS
  the same tree can be a derivation: the scripts get their dependencies wrapped
  onto PATH instead of relying on whatever the user happened to install, and
  ~/.config entries become symlinks into the store, so a rebuild is the only
  way the desktop changes.

  WHAT IS DELIBERATELY NOT DONE HERE: the config files are installed BYTE FOR
  BYTE. They reference $HOME/.local/bin/*.sh and $HOME/.local/state/haku_theme
  throughout, and rewriting those to store paths would fork the configs from
  upstream's and make every future update a merge conflict. The home-manager
  module places the scripts at ~/.local/bin instead, so the references resolve
  and the files stay identical to the ones install.sh writes.
*/

let
  # colorthief drives the wallpaper accent extraction; pygobject3 is for the
  # GTK-based desktop-icon and cava-underbar overlays.
  pythonEnv = python3.withPackages (ps: with ps; [ colorthief pygobject3 ]);

  runtimeDeps =
    [
      bash coreutils findutils gnugrep gnused procps jq libnotify
      rofi waybar swaynotificationcenter cava cliphist wl-clipboard
      grim slurp imagemagick wlr-randr brightnessctl pulseaudio glib
      xdg-utils pythonEnv
    ]
    ++ lib.filter (d: d != null) [
      hyprland hyprlock hypridle hyprpicker hyprsunset gammastep
      mpvpaper awww wl-screenrec kitty thunar
    ];
in
stdenvNoCC.mkDerivation {
  pname = "hakuspace";
  version = "unstable";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/hakuspace $out/bin

    # Configs, window-manager trees and the seed for ~/hakuspace-control,
    # unmodified. The home-manager module decides which of these are linked.
    cp -r src/common/config  $out/share/hakuspace/config
    cp -r src/wm             $out/share/hakuspace/wm
    cp -r assets/hakuspace-control $out/share/hakuspace/control
    cp -r assets/browser     $out/share/hakuspace/browser

    # Scripts keep their .sh/.py names: the configs and keybinds call them by
    # basename under ~/.local/bin, so renaming any of them breaks the callers.
    for f in src/common/local/bin/*; do
      name=$(basename "$f")
      install -Dm755 "$f" "$out/share/hakuspace/scripts/$name"
    done

    patchShebangs $out/share/hakuspace/scripts

    for f in $out/share/hakuspace/scripts/*; do
      name=$(basename "$f")
      makeWrapper "$f" "$out/bin/$name" \
        --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
        --prefix PATH : "$out/bin"
    done

    runHook postInstall
  '';

  /*
    FILE LISTS COMPUTED FROM THE SOURCE TREE, not from $out.

    The home-manager module has to enumerate what it is linking -- every
    script, and every child of the directories that must stay writable. Doing
    that with readDir on "${package}/share/..." would be import-from-derivation:
    the package would have to be BUILT before the configuration could be
    evaluated, so `nix eval` on a host, an editor's LSP, and `nix flake check`
    would all trigger a build. These paths are plain source paths, so they are
    readable during evaluation and cost nothing.
  */
  passthru =
    let
      configDir = ../src/common/config;
      entries = builtins.readDir configDir;
    in
    {
      configNames = builtins.attrNames entries;
      configChildren = lib.mapAttrs (
        name: type:
        if type == "directory" then builtins.attrNames (builtins.readDir (configDir + "/${name}")) else [ ]
      ) entries;
      scriptNames = builtins.attrNames (builtins.readDir ../src/common/local/bin);
    };

  meta = {
    description = "Hyprland / Niri / MangoWM / Labwc dotfiles with a shared Waybar, Rofi and SwayNC desktop";
    homepage = "https://github.com/hakuimaku/hakuspace";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
