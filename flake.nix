{
  description = "NixOS LiveISO responsible of first integration to our infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      confName = "installerISO";

      system = "x86_64-linux";

      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;

      inherit (lib) getBin;

      inherit (pkgs) writeShellScriptBin;
    in
    {

      nixosConfigurations = {

        ${confName} = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs system confName;
          };

          modules = [ ./installer.nix ./overlays ];
        };
      };

      packages.x86_64-linux.buildISO = self.nixosConfigurations.${confName}.config.system.build.isoImage;

      packages.x86_64-linux.generateISO = writeShellScriptBin "bootstrap-${confName}.sh" (
        let
          package = pkgs.nix;
        in
        ''

          [[ $# -gt 0 ]] || set -- --help
          set -x

          ${getBin package}/bin/nix --extra-experimental-features 'nix-command flakes' run nixpkgs#nixos-generators -- \
		--system ${system} \
		--format iso \
		--show-trace --option show-trace true \
		--flake ${self.outPath}#${confName} \
		$@
        ''
      );
    };
}
