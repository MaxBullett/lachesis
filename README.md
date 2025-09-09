# nix-config

A small, modular scaffold for NixOS with Home Manager.

## Layout

```
.
├── flake.nix
├── home/
│   └── max.nix                    # Home Manager config
├── hosts/
│   └── marvin/
│       ├── default.nix            # Host entry point
│       └── hardware-configuration.nix
└── modules/
    ├── hardware/
    │   └── zsa.nix                # Hardware-specific toggles
    ├── programs/
    │   └── cli.nix                # Common CLI tools
    ├── services/
    │   └── docker.nix             # Docker service
    └── system/
        └── base.nix               # Nix/locale/time/stateVersion
```

## Usage

```bash
# build or switch (from repo root)
sudo nixos-rebuild switch --flake .#marvin
```

Add more modules under `modules/` and import them in `hosts/<name>/default.nix`.
Per-host overrides also live in each `hosts/<name>` folder.
```