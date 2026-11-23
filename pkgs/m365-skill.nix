{ lib, stdenvNoCC, requireFile, unzip }:

# The m365 agent skill from intel-manufacturing/applications.manufacturing.intel.ai.agents
# on mfg-github: SKILL.md and its workflow pages, plus the m365-graph-mcp CLI it drives
# at bin/linux-x64/. The binary is a static Go executable, so it runs as shipped.
#
# Nix can't download the release zip (see scripts/update-m365-skill.sh), so this only
# accepts it once that script has put it in the store. The script also bumps
# m365-skill.json, which is all an update touches.
let
  pin = lib.importJSON ./m365-skill.json;
in
stdenvNoCC.mkDerivation {
  pname = "m365-skill";
  inherit (pin) version;

  src = requireFile {
    name = "m365-skill-linux-x64-${pin.version}.zip";
    inherit (pin) hash;
    message = ''
      The m365 skill release zip isn't in the Nix store. From the nixos-config root, run
        ./scripts/update-m365-skill.sh v${pin.version}
      to fetch the pinned release, or with no argument to update to the latest one.
    '';
  };

  nativeBuildInputs = [ unzip ];

  dontBuild = true;
  # Stripping or patching would only rewrite the prebuilt binary.
  dontFixup = true;

  # The zip's only top-level entry is m365/, which unpackPhase makes the source root,
  # so $out becomes the skill directory itself.
  installPhase = ''
    runHook preInstall
    cp -r . $out
    chmod +x $out/bin/linux-x64/m365-graph-mcp
    runHook postInstall
  '';

  meta = {
    description = "Microsoft 365 agent skill and the m365-graph-mcp CLI it drives";
    platforms = [ "x86_64-linux" ];
  };
}
