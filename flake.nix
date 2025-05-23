{
  description = "Add patches to nixpkgs seamlessly";

  outputs = _: {
    lib.nixosSystem =
      # TODO: don't hardcode system
      # maybe try to wrap it in a function (that is used to replace nixosSystem)
      # and get nixpkgs.hostPlatform from the config?
      { system, inputs }:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
        # take "nixpkgs" input as a base and apply patches that start with "nixpkgs-patch"
        patches = builtins.attrValues (
          inputs.nixpkgs.lib.filterAttrs (n: v: builtins.match "^nixpkgs-patch-.*" n != null) inputs
        );
        patchedNixpkgs = pkgs.applyPatches {
          name = "nixpkgs-patched";
          src = inputs.nixpkgs;
          inherit patches;
        };
        # don't use the patchedNixpkgs without patches, it takes time to build it
        finalNixpkgs = if patches == [ ] then inputs.nixpkgs else patchedNixpkgs;
        nixosSystem = import "${finalNixpkgs}/nixos/lib/eval-config.nix";
      in
      nixosSystem;
  };
}
