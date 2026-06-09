{ config, pkgs, ... }:

{
  age.secrets.rclone-gdrive = {
    file = ../secrets/rclone-gdrive.age;
    owner = "maixnor";
  };
}
