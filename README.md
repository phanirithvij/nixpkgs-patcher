
# nixpkgs-patcher

Using [nixpkgs](https://github.com/NixOS/nixpkgs) pull requests that haven't landed into your channel has never been easier!

## Getting Started

### Install nixpkgs-patcher

Modify your flake accordingly:
- Use `nixpkgs-patcher.lib.nixosSystem` instead of `nixpkgs.lib.nixosSystem`
- Ensure that you pass the `inputs` to `specialArgs`

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
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
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

Create a new input that starts with `nixpkgs-patch-`, which points to the diff of your PR and indicates that it's not a flake. In this example, we perform a package bump for `git-review`. The PR number is `410328`, and we take the diff between the master branch and it.

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/compare/master...pull/410328/head.diff";
      flake = false;
    };
  };
}
```

Rebuild your system and enjoy using the PRs early! This is likely everything you need to know to use this flake effectively. However, there are additional configuration options for more advanced use cases.

## Configuration

### Using Different Base nixpkgs

By default, this flake assumes that you have an input called `nixpkgs`. It's possible that you have `nixpkgs-unstable` and `nixpkgs-stable` (or named them entirely differently). In that case, you can configure which should be used as a base.

```nix
# file: flake.nix
{
  outputs =
    { nixpkgs-patcher, nixpkgs-stable, nixpkgs-unstable, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        nixpkgsPatcher.nixpkgs = nixpkgs-unstable;
      };
    };
}
```

### Avoiding `specialArgs` Pollution

If you don't want to pass down every input to `specialArgs`, or if you have a different structure for it, you can provide your inputs in another way.

```nix
# file: flake.nix
{
  outputs =
    { nixpkgs-patcher, foo-flake, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        specialArgs = { inherit (inputs) foo-flake }; # keep your specialArgs however it was before
        nixpkgsPatcher.inputs = inputs;
      };
    };
}
```

### Naming Patches Differently

If you don't want to start every patch's name with `nixpkgs-patch-`, you can change the regex that is used to filter the inputs.

```nix
# file: flake.nix
{
  inputs = {
    # ...
    # all of these will be treated as patches because they contain "nix-pr"
    git-review-nix-pr = ...;
    nix-pr-mycelium = ...;
  };

  outputs =
    { nixpkgs-patcher, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        nixpkgsPatcher.patchInputRegex = ".*nix-pr.*"; # default: "^nixpkgs-patch-.*"
      };
    };
}
```

## Adding Patches

### Using Flake Inputs

This is the fastest way in my opinion, because all you have to do is add a flake input. Updating flake inputs will also update your patches. Here are some examples:

```nix
# file: flake.nix
{
  inputs = {
    # ...

    # include a package bump from a nixpkgs PR
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/compare/master...pull/410328/head.diff";
      flake = false;
    };

    # include a new module from a nixpkgs PR
    nixpkgs-patch-lasuite-docs-module-init = {
      url = "https://github.com/NixOS/nixpkgs/compare/master...pull/401798/head.diff";
      flake = false;
    };

    # include a patch from your (or someone else's) fork of nixpkgs by a branch name
    nixpkgs-patch-lasuite-docs-module-init = {
      url = "https://github.com/NixOS/nixpkgs/compare/master...gepbird:nixpkgs:xppen-init-v3-v4-nixos-module";
      flake = false;
    };

    # local patch (don't forget to git add the file!)
    nixpkgs-patch-git-review-bump = {
      url = "./patches/git-review-bump.patch";
      flake = false;
    };

    # patches are ordered and applied alphabetically; if one patch depends on another, you can prefix them with a number to make the ordering clear
    nixpkgs-patch-10-mycelium-0-6-0 = {
      url = "https://github.com/NixOS/nixpkgs/compare/pull/master...pull/402466/head.diff";
      flake = false;
    };
    nixpkgs-patch-20-mycelium-0-6-1 = {
      url = "https://github.com/NixOS/nixpkgs/compare/pull/master...pull/410367/head.diff";
      flake = false;
    };

    # don't compare against master, but take the last x (in this case 5) commits of the PR
    nixpkgs-patch-lasuite-docs-module-init = {
      url = "https://github.com/NixOS/nixpkgs/compare/pull/401798/head~5...pull/401798/head.diff";
      flake = false;
    };
  };
}
```

> [!WARNING]  
> Using URLs like `https://github.com/NixOS/nixpkgs/pull/410328.diff` may be shorter and more convenient, but please be aware that this approach was unofficially rate limited to approximately 1 request per minute, with an initial limit of 5 requests in the past. It is advisable to use the longer format to avoid potential issues.

### Using nixpkgsPatcher Config

You can also define patches similarly to how you configured this flake. Provide a `nixpkgsPatcher.patches` attribute to `nixosSystem` that takes in `pkgs` and outputs a list of patches.

```nix
# file: flake.nix
{
  outputs =
    { nixpkgs-patcher, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        nixpkgsPatcher.patches =
          pkgs: with pkgs; [
            (fetchpatch2 {
              name = "git-review-bump.patch";
              url = "https://github.com/NixOS/nixpkgs/compare/master...pull/410328/head.diff";
              hash = ""; # rebuild, wait for nix to fail and give you the hash, then put it here
            })
            (fetchpatch2 {
              # ...
            })
          ];
      };
    };
}
```

### Using Your Configuration

After installing nixpkgs-patcher, you can apply patches from your config without touching flake.nix.

```nix
# file: configuration.nix
{ pkgs, ... }: 

{
  environment.systemPackages = with pkgs; [
    # ...
  ];

  nixpkgs-patcher = {
    enable = true;
    settings.patches = with pkgs; [
      (fetchpatch2 {
        name = "git-review-bump.patch";
        url = "https://github.com/NixOS/nixpkgs/compare/master...pull/410328/head.diff";
        hash = ""; # rebuild, wait for nix to fail and give you the hash, then put it here
      })
    ];
  };
}
```

## TODO

- work with other flake outputs, not just `nixosConfiguration`

## Comparison with Alternatives

This flake focuses on ease of use for patching nixpkgs and using it with NixOS.
It requires less effort to understand and quickly start using it compared to alternatives.
However, if you want to patch other flake inputs or use patches inside packages or devshells, check out the alternatives!

| | nixpkgs-patcher | [nix-patcher](https://github.com/katrinafyi/nix-patcher) | [flake-input-patcher](https://github.com/jfly/flake-input-patcher) |
|------------------------------                                               |----|----|----|
| Patches from flake inputs                                                   | ✅ | ✅ | ❌ |
| Patches using fetchpatch                                                    | ✅ | ❌ | ✅ |
| Patches in NixOS modules                                                    | ✅ | ❌ | ❌ |
| Local only                                                                  | ✅ | ❌ | ✅ |
| No extra eval time for local patching (cached)                              | ❌ | ✅ | ❌ |
| Doesn't require additional tools                                            | ✅ | ❌ | ✅ |
| Automatic `system` detection                                                | ✅ | ✅ | ❌ |
| Works for any flake                                                         | ❌ | ✅ | ✅ |
| [IFD](https://nix.dev/manual/nix/2.29/language/import-from-derivation) free | ❌ | ✅ | ❌ |

### Why Not Just Use Overlays?

For individual packages, using overlays can appear straightforward:

1. Add the forked nixpkgs by a branch reference:

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-git-review-bump.url = "github:kira-bruneau/nixpkgs/git-review";
  };
}
```

2. Apply it with an overlay:

```nix
# file: configuration.nix
{ pkgs, nixpkgs-git-review-bump, ... }: 

let
  pkgs-git-review = import nixpkgs-git-review-bump { inherit (pkgs) system; };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      git-review = pkgs-git-review.git-review;
    })
  ];
}
```

Package sets such as KDE (and previously GNOME) have their own way of [overriding packages](https://wiki.nixos.org/wiki/KDE#Customizing_nixpkgs).

Overriding modules becomes finicky when you want to try out a module update PR. You must disable the old module first, add the module from the PR, and reference relative file paths, all while hoping that it works in the end. And add dependant packages with overlays.

```nix
# file: configuration.nix
{ pkgs, nixpkgs-pocket-id, ... }:

{
  disabledModules = [
    "services/security/pocket-id.nix"
  ];
  imports = [
    "${nixpkgs-pocket-id}/nixos/modules/services/security/pocket-id.nix"
  ];

  nixpkgs.overlays =
    let
      pkgs-pocket-id = import nixpkgs-pocket-id { inherit (pkgs) system; };
    in
    [
      (final: prev: {
        pocket-id = pkgs-pocket-id.pocket-id;
      })
    ];
}
```

## Contributing

Bug reports, feature requests, and PRs are welcome!

## Credits

- people involved in [the issue about patching flake inputs](https://github.com/NixOS/nix/issues/3920)
- [patch-nixpkgs article](https://ertt.ca/nix/patch-nixpkgs/)
- [flake-input-patcher](https://github.com/jfly/flake-input-patcher)
- [nix-patcher](https://github.com/katrinafyi/nix-patcher)
