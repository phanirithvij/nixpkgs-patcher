{ pkgs, ... }:

{
  boot.loader.grub.device = "nodev";

  system.stateVersion = "25.05";
}
