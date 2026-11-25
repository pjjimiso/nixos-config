## General
- You're running in NixOS, so if something isn't installed then first try to grab it from the nix store with `nix-shell -p <pkg>`
- When reporting information to me, be extremely concise. Sacrifice grammar for the sake of concision. 

## Git Workflow
- Never assume that you should stage or commit a change unless I ask you to. I like to review your changes unstaged.
- When I ask you to commit and push, push to a new feature branch (not `main`) if you aren't already on one.
- Rebase off of the `main` branch before pushing, unless I ask for something else.
- Look at the `git log` after rebasing. If there are any sloppy "wip" or "fixup" commits, squash them into the most logical commit message before pushing.
- Use short, single-sentence conventional commit messages.
- Never create a pull request without being asked to.
