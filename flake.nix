{
  description = "Add patches to nixpkgs seamlessly";

  outputs = _: {
    lib.nixosSystem =
      args:
      let
        die = msg: throw "[nixpkgs-patcher]: ${msg}";

        config = args.nixpkgsPatcher or { };
        inputs =
          config.inputs or args.specialArgs
            or (die "Couldn't find your flake inputs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.inputs = inputs` or `specialArgs = inputs`.");
        nixpkgs =
          config.nixpkgs or inputs.nixpkgs
            or (die "Couldn't find your base nixpkgs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.nixpkgs = inputs.nixpkgs` or name your main nixpkgs input `nixpkgs` and pass `specialArgs = inputs`.");
        patchInputRegex = config.patchInputRegex or "^nixpkgs-patch-.*";
        systemInput = config.system or args.system or null;

        system =
          if systemInput != null then
            systemInput
          else
            (import "${nixpkgs}/nixos/lib/eval-config.nix" args).config.nixpkgs.hostPlatform.system;

        pkgs = import nixpkgs { inherit system; };
        # take "nixpkgs" input as a base and apply patches that start with "nixpkgs-patch"
        patches = builtins.attrValues (
          nixpkgs.lib.filterAttrs (n: v: builtins.match patchInputRegex n != null) inputs
        );
        patchedNixpkgs = pkgs.applyPatches {
          name = "nixpkgs-patched";
          src = nixpkgs;
          inherit patches;
        };
        # don't use the patchedNixpkgs without patches, it takes time to build it
        finalNixpkgs = if patches == [ ] then nixpkgs else patchedNixpkgs;

        args' = builtins.removeAttrs args [ "nixpkgsPatcher" ];
        nixosSystem = import "${finalNixpkgs}/nixos/lib/eval-config.nix" args';
      in
      nixosSystem;
  };
}
