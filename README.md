# Nix Config Repository

This repository provides a flake-driven, modular configuration for NixOS. It is designed to be reusable, declarative, and easy to extend.

## What you can do with it
- Define and build full NixOS systems from a single source of truth
- Organize configuration into reusable modules
- Produce images or other build artifacts

## Prerequisites
- Nix with flakes and `nix-command` enabled (Nix 2.18+ recommended)
- Git

## Building and switching configurations
- Switch a NixOS host to a configuration defined in this flake:
  ```sh
  nh os switch -H <host>
  ```
- Build a system configuration without switching:
  ```sh
  nh os build -H <host>
  ```

## Templates
You can use templates to generate boilerplate code.
- To list available templates:
  ```sh
  nix shell .#mkTemplate -c mkTemplate list
  ```
- To generate a template:
  ```sh
  nix shell .#mkTemplate -c mkTemplate <template> <name>
  ```

## Common tasks
- Update inputs (pins are tracked in `flake.lock`):
  ```sh
  nix flake update
  ```
- Collect garbage and free store space:
  ```sh
  nix-collect-garbage -d
  nix store gc
  ```
- Roll back to a previous NixOS generation:
  ```sh
  sudo nixos-rebuild --rollback
  ```

## Repository layout
- `flake.nix` — Entry point defining inputs, outputs, and how configurations are composed
- `flake.lock` — Pinned dependency set for reproducibility
- `nix/` — Main directory for project code and data
  - `hosts/` — Host-specific system configurations (one directory per host)
  - `modules/` — Reusable building blocks split by scope (e.g., system or user)
    - `nixos/` — System-wide building blocks (nixosModules)
    - `home/` — User-level building blocks (homeModules)
  - `packages/` — Custom packages exposed by the flake
  - `templates/` — Boilerplate or scaffolding utilities
  - `lib/` — Small helpers and functions used by modules/outputs
  - `devshell.nix` — Developer shell definition
  - `formatter.nix` — Project-wide formatter settings
- `result/` — Build symlinks created by `nix build` (managed by Nix; safe to remove)

## Customizing
- Add or modify modules under `nix/modules/` and compose them in your system configuration
- Introduce a new host by adding a directory under `nix/hosts/<name>/` and wiring it into your flake outputs
- Add custom packages under `nix/packages/` if needed

## Tips
- This is a work in progress, so expect things to change and break!
- Keep `flake.lock` committed to ensure reproducible builds across hosts
- Use branches and PRs to review configuration changes like regular code
- Prefer small, focused modules to maximize reuse
