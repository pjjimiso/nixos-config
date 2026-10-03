{ lib, inputs, ... }:

# Agent skills, installed globally so every project on every machine sees them.
#
# Everything lands in ~/.claude/skills/<name>, the one global path BOTH harnesses
# scan: Claude Code natively, and opencode via its Claude-compatibility paths
# (opencode also checks ~/.config/opencode/skills and ~/.agents/skills, but one
# copy here is enough -- duplicating would list every skill twice).
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
  };

  localSkills = lib.optionalAttrs (builtins.pathExists ./skills) (skillsIn ./skills);

  allSkills = mattpocockSkills // extraSkills // localSkills;
in
{
  home.file = lib.mapAttrs' (name: source:
    lib.nameValuePair ".claude/skills/${name}" { inherit source; }) allSkills;
}
