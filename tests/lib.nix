{ nixpkgs }:

let
  inherit (nixpkgs) lib;
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  runTests =
    tests:
    let
      failedTests = lib.debug.runTests tests;
    in
    if (builtins.length failedTests) != 0 then throw (builtins.toJSON failedTests) else pkgs.hello;
in
{
  inherit runTests;
}
