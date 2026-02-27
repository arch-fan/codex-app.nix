{
  description = "Simple flake for codex-app on x86_64-linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [ "codex-app" ];
      };
      codexApp = pkgs.callPackage ./package.nix { };
    in {
      packages.${system} = {
        codex = codexApp;
        codex-app = codexApp;
        default = codexApp;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${codexApp}/bin/codex-app";
        };

        update = {
          type = "app";
          program = "${codexApp.passthru.updateScript}/bin/update-codex-app";
        };
      };
    };
}
