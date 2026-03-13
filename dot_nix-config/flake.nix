{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-25.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Pinned Nix 2.35.1. No `follows` so the binary substitutes from
    # cache.nixos.org.
    nix.url = "github:NixOS/nix/2.35.1";
    # Local flakes via username-free symlinks (see systemd.tmpfiles.rules in
    # configuration.nix): /var/lib/nix-flakes/{helix,cinny} -> real repos.
    # git+file follows the symlink; the committed URL has no username.
    cinny-local.url = "git+file:/var/lib/nix-flakes/cinny";
    helix-local = {
      url = "git+file:/var/lib/nix-flakes/helix";
      # helix pins its own nixpkgs (currently 26.05.20260401) whose
      # importCargoLock still uses crates.io/api/v1, which now 403s nixpkgs'
      # curl User-Agent. Reuse our nixpkgs (25.11) which vendors from
      # static.crates.io.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    voxtype = {
      url = "github:peteonrails/voxtype/dev";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    herdr = {
      url = "github:herdrdev/herdr";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    gws = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # See private.nix.example — copy to private.nix and fill in your values (not committed).
      private = import ./private.nix { inherit pkgs; };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          (
            { ... }:
            {
              nix.settings.substituters = [
                "https://nix-community.cachix.org"
                "https://devenv.cachix.org"
                "https://attic.xuyh0120.win/lantian"
              ];
              nix.settings.trusted-public-keys = [
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
                "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
              ];
            }
          )
          (
            { pkgs, ... }:
            {
              nixpkgs.overlays = [
                inputs.nix-cachyos-kernel.overlays.pinned
              ];
              boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
            }
          )
          ./configuration.nix
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${private.username} = import ./home.nix;
            home-manager.extraSpecialArgs = {
              unstable = import inputs.nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };

              inherit (inputs) voxtype herdr cinny-local gws;
              inherit (private) username;
              llamaCpp = inputs.llama-cpp;
            };
          }
        ];
        specialArgs = {
          inherit inputs;
          unstable = import inputs.nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          inherit (private) username description audioNodes nebulaServices sambaShares vmSshKey;
          helix-local = inputs.helix-local;
          voxtype = inputs.voxtype;
        };
      };
    };
}
