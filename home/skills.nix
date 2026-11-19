{ config, lib, inputs, ... }:

# Agent skills, installed globally so every project on every machine sees them.
#
# The one real copy lives in ~/.agents/skills/<name>, the cross-tool path opencode
# scans. Claude Code only reads ~/.claude/skills, so each skill also gets a
# symlink there pointing back at ~/.agents/skills/<name>. opencode scans
# ~/.claude/skills too, but it picks skills by ID (later sources win), so the same
# skill found in both places loads once.
#
# Don't install skills with `npx skills`: it writes real directories into
# ~/.agents/skills, and Home Manager won't replace them on the next switch.
#
# To install another skill (e.g. an Elasticsearch one), either:
#   * add its repo as a `flake = false` input in flake.nix and one line in
#     `extraSkills` below pointing at the directory containing its SKILL.md, or
#   * commit it to this repo under home/skills/<name>/SKILL.md -- the local
#     directory is auto-discovered.
let
  # name -> source for every skill subdirectory of `dir` (README.md etc. ignored).
  skillsIn = dir:
    lib.mapAttrs' (name: _: lib.nameValuePair name "${dir}/${name}")
      (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

  # mattpocock/skills: same set as upstream's Claude Code plugin ships -- all of
  # engineering/ and productivity/. The repo's misc/, in-progress/ and deprecated/
  # categories are excluded from the plugin upstream too.
  mattpocockSkills =
    skillsIn "${inputs.mattpocock-skills}/skills/engineering"
    // skillsIn "${inputs.mattpocock-skills}/skills/productivity";

  extraSkills = {
    # Invoke with /i-have-adhd; "stop adhd mode" turns it off for the session.
    # Its opencode plugin counterpart is wired up in default.nix.
    i-have-adhd = "${inputs.i-have-adhd}/skills/i-have-adhd";
    find-skills = "${inputs.vercel-skills}/skills/find-skills";
  };

  localSkills = lib.optionalAttrs (builtins.pathExists ./skills) (skillsIn ./skills);

  allSkills = mattpocockSkills // extraSkills // localSkills;

  agentsDir = "${config.home.homeDirectory}/.agents/skills";
in
{
  home.file =
    lib.mapAttrs' (name: source:
      lib.nameValuePair ".agents/skills/${name}" { inherit source; }) allSkills
    // lib.mapAttrs' (name: _:
      lib.nameValuePair ".claude/skills/${name}" {
        source = config.lib.file.mkOutOfStoreSymlink "${agentsDir}/${name}";
      }) allSkills;
}
