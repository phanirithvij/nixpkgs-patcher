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
                { lib, ... }:

                let
                  inherit (lib)
                    mkOption
                    mkEnableOption
                    literalExpression
                    types
                    ;
                in
                {
                  # TODO: set config.nixpkgs.flake.source

                  options.nixpkgs-patcher = {
                    enable = mkEnableOption "nixpkgs-patcher";
                    settings = mkOption {
                      type = types.submodule {
                        options = {
                          patches = lib.mkOption {
                            type = types.listOf types.package;
                            default = [ ];
                            example = literalExpression ''
                              [
                                (pkgs.fetchpatch2 {
                                  name = "foo-module-init.patch";
                                  url = "https://github.com/NixOS/nixpkgs/compare/pull/123456/head~1...pull/123456/head.patch";
                                  hash = "";
                                })
                              ]
                            '';
                            description = ''
                              A list of patches to apply to the nixpkgs source.
                            '';
                          };
                        };
                      };
                      default = { };
                    };
                  };
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
        patchesFromConfig = config.patches or args.patches or (_: [ ]);

        inherit (nixpkgs.lib)
          filterAttrs
          ;

        evaledModules = import "${nixpkgs}/nixos/lib/eval-config.nix" args';
        system =
          if args'.system != null then args'.system else evaledModules.config.nixpkgs.hostPlatform.system;
        pkgs = import nixpkgs { inherit system; };

        moduleConfig = evaledModules.config.nixpkgs-patcher;
        patchesFromModules = if moduleConfig.enable then moduleConfig.settings.patches else [ ];

        patchesFromFlakeInputs = attrValues (filterAttrs (n: v: match patchInputRegex n != null) inputs);

        patches = (patchesFromConfig pkgs) ++ patchesFromFlakeInputs ++ patchesFromModules;
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
