{
  description = "Add patches to nixpkgs seamlessly";

  outputs = _: {
    lib.nixosSystem =
      args:
      let
        inherit (builtins)
          attrValues
          match
          removeAttrs
          ;

        die = msg: throw "[nixpkgs-patcher]: ${msg}";

        # maybe try to import the flake instead, this is for mostly replicating nixosSystem from the flake:
        # https://github.com/NixOS/nixpkgs/blob/a61befb69a171c7fe6fb141fca18e40624d7f55f/flake.nix#L64-L95
        args' =
          {
            system = null;
            modules = args.modules ++ [
              (
                { ... }:
                {
                  # TODO: set config.nixpkgs.flake.source
                }
              )
            ];
          }
          // removeAttrs args [
            "modules"
            "nixpkgsPatcher"
            "patches"
          ];

        config = args.nixpkgsPatcher or { };
        inputs =
          config.inputs or args.specialArgs
            or (die "Couldn't find your flake inputs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.inputs = inputs` or `specialArgs = inputs`.");
        nixpkgs =
          config.nixpkgs or inputs.nixpkgs
            or (die "Couldn't find your base nixpkgs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.nixpkgs = inputs.nixpkgs` or name your main nixpkgs input `nixpkgs` and pass `specialArgs = inputs`.");
        patchInputRegex = config.patchInputRegex or "^nixpkgs-patch-.*";
        systemInput = config.system or args'.system;
        patchesFromConfig = config.patches or args.patches or [ ];

        system =
          if systemInput != null then
            systemInput
          else
            (import "${nixpkgs}/nixos/lib/eval-config.nix" args').config.nixpkgs.hostPlatform.system;

        pkgs = import nixpkgs { inherit system; };

        inherit (nixpkgs.lib)
          filterAttrs
          ;

        patchesFromFlakeInputs = attrValues (filterAttrs (n: v: match patchInputRegex n != null) inputs);

        patches = (patchesFromConfig pkgs) ++ patchesFromFlakeInputs;
        patchedNixpkgs = pkgs.applyPatches {
          # TODO: add more metadata
          name = "nixpkgs-patched";
          src = nixpkgs;
          inherit patches;
        };
        finalNixpkgs = if patches == [ ] then nixpkgs else patchedNixpkgs;

        nixosSystem = import "${finalNixpkgs}/nixos/lib/eval-config.nix" args';
      in
      nixosSystem;
  };
}
