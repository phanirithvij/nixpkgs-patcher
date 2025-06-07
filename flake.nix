{
  description = "Add patches to nixpkgs seamlessly";

  outputs = _: {
    lib.nixosSystem =
      args:
      let
        inherit (builtins)
          match
          removeAttrs
          ;

        die = msg: throw "[nixpkgs-patcher]: ${msg}";

        # maybe try to import the flake instead, this is for mostly replicating nixosSystem from the flake:
        # https://github.com/NixOS/nixpkgs/blob/a61befb69a171c7fe6fb141fca18e40624d7f55f/flake.nix#L64-L95
        metadataModule =
          { lib, ... }:
          {
            config.nixpkgs.flake.source = toString patchedNixpkgs;

            config.system.nixos.versionSuffix = ".${
              lib.substring 0 8 nixpkgs.lastModifiedDate or "19700101"
            }.${nixpkgs.shortRev or "dirty"}${if patches != [ ] then "-patched" else ""}";

            config.system.nixos.revision = nixpkgs.rev;
          };

        nixpkgsPatcherNixosModule =
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
            options.nixpkgs-patcher = {
              enable = mkEnableOption "nixpkgs-patcher";
              settings = mkOption {
                type = types.submodule {
                  options = {
                    patches = lib.mkOption {
                      type = types.listOf (types.either types.path types.package);
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
          };

        dontCheckModule =
          { ... }:
          {
            # disable checking for an option doesn't exist and others
            # needed when an option is only available in the patched nixpkgs
            # but not in the original one
            _module.check = false;
          };

        args' =
          {
            system = null;
            modules = args.modules ++ [
              metadataModule
              nixpkgsPatcherNixosModule
            ];
          }
          // removeAttrs args [
            "modules"
            "nixpkgsPatcher"
          ];

        config = args.nixpkgsPatcher or { };
        inputs =
          config.inputs or args.specialArgs
            or (die "Couldn't find your flake inputs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.inputs = inputs` or `specialArgs = inputs`.");
        nixpkgs =
          config.nixpkgs or inputs.nixpkgs
            or (die "Couldn't find your base nixpkgs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.nixpkgs = inputs.nixpkgs` or name your main nixpkgs input `nixpkgs` and pass `specialArgs = inputs`.");
        patchInputRegex = config.patchInputRegex or "^nixpkgs-patch-.*";
        patchesFromConfig = config.patches or (_: [ ]);

        inherit (nixpkgs.lib)
          attrsToList
          filterAttrs
          ;

        evalArgs = args' // {
          modules = args'.modules ++ [ dontCheckModule ];
        };
        evaledModules = import "${nixpkgs}/nixos/lib/eval-config.nix" evalArgs;
        system =
          if args'.system != null then args'.system else evaledModules.config.nixpkgs.hostPlatform.system;
        pkgs = import nixpkgs { inherit system; };

        moduleConfig = evaledModules.config.nixpkgs-patcher;
        patchesFromModules = if moduleConfig.enable then moduleConfig.settings.patches else [ ];

        patchesFromFlakeInputsRaw = attrsToList (
          filterAttrs (n: v: match patchInputRegex n != null) inputs
        );
        # this is for setting a nicer name for the patch in the build log
        patchesFromFlakeInputs = map (
          patch:
          pkgs.stdenvNoCC.mkDerivation {
            inherit (patch) name;

            phases = [ "installPhase" ];
            installPhase = ''
              cp -r ${patch.value.outPath} $out
            '';
          }
        ) patchesFromFlakeInputsRaw;

        patches = (patchesFromConfig pkgs) ++ patchesFromFlakeInputs ++ patchesFromModules;
        patchedNixpkgs = pkgs.applyPatches {
          name = "nixpkgs-patched";
          src = nixpkgs;

          inherit patches;

          nativeBuildInputs = with pkgs; [
            bat
          ];

          failureHook = ''
            find . -name "*.rej" -exec bat --pager never {} +
          '';
        };
        finalNixpkgs = if patches == [ ] then nixpkgs else patchedNixpkgs;

        nixosSystem = import "${finalNixpkgs}/nixos/lib/eval-config.nix" args';
      in
      nixosSystem;
  };
}
