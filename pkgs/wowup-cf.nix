{ lib, appimageTools, fetchurl }:

let
  pname = "wowup-cf";
  # nixos-25.05 ships 2.20.0, which predates WoW Forever support (added in 2.24.0).
  version = "2.25.4";
  src = fetchurl {
    url = "https://github.com/WowUp/WowUp.CF/releases/download/v${version}/WowUp-CF-${version}.AppImage";
    # Bump with: nix store prefetch-file <url>
    hash = "sha256-tKOFboaUo1wgLJ2xjLPOyqHrf8Do+oS0ZzL2fcs8Jc4=";
  };
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';
  meta = {
    description = "World of Warcraft addon updater with CurseForge support";
    homepage = "https://wowup.io/";
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
