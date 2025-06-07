#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix
for testDir in */; do
  pushd $testDir
  # TODO: figure out why it's broken with cppnix
  #nix run github:NixOS/nixpkgs#nixVersions.stable -- flake check
  nix run github:NixOS/nixpkgs#lixVersions.stable -- flake check
  popd
done
