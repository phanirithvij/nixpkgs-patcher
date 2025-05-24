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

        inherit (builtins)
          attrValues
          match
          removeAttrs
          ;
        inherit (nixpkgs.lib)
          filterAttrs
          ;

        patches = attrValues (filterAttrs (n: v: match patchInputRegex n != null) inputs);
        patchedNixpkgs = pkgs.applyPatches {
          name = "nixpkgs-patched";
          src = nixpkgs;
          inherit patches;
        };
        finalNixpkgs = if patches == [ ] then nixpkgs else patchedNixpkgs;

        args' = removeAttrs args [ "nixpkgsPatcher" ];
        nixosSystem = import "${finalNixpkgs}/nixos/lib/eval-config.nix" args';
      in
      nixosSystem;
  };
}
