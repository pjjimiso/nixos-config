# nixos-config

Personal NixOS and home-manager configuration using [Nix Flakes](https://nixos.wiki/wiki/Flakes).

## Structure

```
nixos-config/
├── flake.nix                     # Flake inputs/outputs
├── modules/
│   └── common.nix                # Shared system packages and Nix settings
├── home/
│   └── default.nix               # Shared home-manager config (dotfiles, env)
└── hosts/
    ├── wsl/
    │   └── configuration.nix     # NixOS WSL (corporate network)
    └── legion/
        ├── configuration.nix     # Lenovo Legion laptop (Cinnamon desktop)
        └── hardware.nix          # Hardware-specific config (generated on device)
```

## Hosts

| Host | Description |
|------|-------------|
| `wsl` | NixOS-WSL (Corporate proxy) |
| `legion` | Lenovo Legion running NixOS with Cinnamon |


## Bootstrap New Machine
After installing NixOS, clone the repo
```
nix shell nixpkgs#git --command git clone https://github.com/pjjimiso/nixos-config ~/nixos-config
```

Rebuild 
```
sudo nixos-rebuild switch --flake .#hostname
```

Add git token to gh auth
```
mkdir -p ~/.config/sops/age
bw login && bw get notes "nixos-age-key" > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
sudo nixos-rebuild switch --flake .#hostname
```
After that, gh should authenticate automatically on every login. See
[GitHub PAT (SOPS)](#github-pat-sops) for rotating the token itself.

## Usage

### NixOS machines

Rebuild WSL

```bash
sudo nixos-rebuild switch --flake .#wsl
```

Rebuild Legion

```bash
sudo nixos-rebuild switch --flake .#legion
```

Update Bootdev cli (non-flake git input)
```bash
nix flake update bootdev-src
nix build .#bootdev
```

### Non-NixOS machines (standalone home-manager)

First, install Nix and home-manager, then clone this repo:

```bash
git clone https://github.com/pjjimiso/nixos-config ~/.config/nixos-config
cd ~/.config/nixos-config
```

Apply the appropriate profile:

```bash
# Corp network
home-manager switch --flake .#corporate

# Personal/home network
home-manager switch --flake .#personal
```

### Restricted machines (no Nix available)

Clone nvim config manually:

```bash
git clone https://github.com/pjjimiso/kickstart.nvim ~/.config/nvim
```

## GitHub PAT (SOPS)

The GitHub PAT is stored encrypted in `secrets/secrets.yaml` under the
`github_pat` key, sealed to the age key listed in `.sops.yaml`.

| Piece | Location |
|-------|----------|
| Encrypted secret | `secrets/secrets.yaml` (`github_pat`) |
| Age private key | `~/.config/sops/age/keys.txt` (from Bitwarden, see bootstrap) |
| Recipients | `.sops.yaml` |
| Secret declaration | `home/default.nix` (`sops.secrets.github_pat`) |
| Consumer | `gh-auth.service` user unit in `home/default.nix` |

On login, `gh-auth.service` pipes the decrypted PAT into
`gh auth login --with-token`.

### Generating a new PAT

Create a classic token at <https://github.com/settings/tokens>

### Rotating the token

1. Edit the secret in place. `sops` decrypts into `$EDITOR`, then re-encrypts on
   save — replace the `github_pat` value and quit:

   ```bash
   nix-shell -p sops --run 'sops secrets/secrets.yaml'
   ```

2. Rebuild so sops-nix re-decrypts the secret to its runtime path:

   ```bash
   sudo nixos-rebuild switch --flake .#wsl
   ```

3. Force `gh` onto the new token. `gh-auth.service` is guarded by
   `if ! gh auth status`, so while the old token is still valid the service
   skips re-authenticating — the logout is what makes the swap happen now
   rather than whenever the old token expires:

   ```bash
   gh auth logout --hostname github.com
   systemctl --user restart gh-auth
   gh auth status
   ```

4. Commit the re-encrypted secret (ciphertext only, safe to push):

   ```bash
   git commit -am "Rotate github PAT"
   ```

If `gh auth status` reports a `gho_*` token, that came from an interactive
`gh auth login` web flow rather than from this pipeline; a PAT from
`secrets.yaml` shows as `ghp_*` or `github_pat_*`.

## Adding a new host

1. Create `hosts/<hostname>/configuration.nix`
2. For physical machines, generate hardware config on the device and save it to
   `hosts/<hostname>/hardware.nix`:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware.nix
   ```
3. Add the host to `flake.nix` under `nixosConfigurations`
