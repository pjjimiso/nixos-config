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


## Usage

### NixOS machines

Apply configuration on the WSL:

```bash
sudo nixos-rebuild switch --flake .#wsl
```

Apply configuration on the Legion:

```bash
sudo nixos-rebuild switch --flake .#legion
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

## Adding a new host

1. Create `hosts/<hostname>/configuration.nix`
2. For physical machines, generate hardware config on the device and save it to
   `hosts/<hostname>/hardware.nix`:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware.nix
   ```
3. Add the host to `flake.nix` under `nixosConfigurations`
