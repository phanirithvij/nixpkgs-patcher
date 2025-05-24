# nixpkgs-patcher

Using [nixpkgs](https://github.com/NixOS/nixpkgs) pull requests that haven't landed into your channel has never been easier!

## Getting Started

### Install nixpkgs-patch

Modify your flake accordingly:
- use `nixpkgs-patcher.lib.nixosSystem` instead of `nixpkgs.lib.nixosSystem`
- ensure that you pass the `inputs` to `specialArgs`

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
  };

  outputs =
    { nixpkgs-patcher, ... }@inputs:
    {
      nixosConfigurations.yourhostname = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
        specialArgs = inputs;
      };
    };
}
```

### Add a PR

Create a new input that starts with `nixpkgs-patch-`, which points to the diff of your PR and indicates that it's not a flake. In this example, we perform a package bump for `git-review`. The PR number is `410328` (included twice in the link), and the `~1` indicates that we want the diff of the last commit.

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/compare/pull/410328/head~1...pull/410328/head.diff"
      flake = false;
    };
  };
}
```
