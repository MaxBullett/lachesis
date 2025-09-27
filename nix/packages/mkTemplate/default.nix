{ pkgs }:
pkgs.writeShellApplication {
  name = "mkTemplate";
  runtimeInputs = [
    pkgs.findutils   # find
    pkgs.coreutils   # mkdir, mv, etc.
    pkgs.gnused      # sed (if you add other templates later)
    pkgs.git         # repo-root detection
  ];
  text = builtins.readFile ./mkTemplate.sh;
}
