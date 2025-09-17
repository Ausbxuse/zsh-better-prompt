{
  description = "Zsh vi-cursor + prompt timing plugin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = f:
      builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        })
        systems);
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.stdenv.mkDerivation {
        pname = "zsh-cursor-prompt";
        version = "0.1.0";
        src = self;
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/share/better-prompt
          cp better-prompt/better-prompt.zsh \
             $out/share/better-prompt/better-prompt.zsh
        '';
        meta = with pkgs.lib; {
          description = "Zsh vi-mode cursor shapes, timing in RPROMPT, VCS info";
          license = licenses.mit;
          platforms = platforms.unix;
        };
      };
    });

    overlays.default = final: prev: {
      zsh-cursor-prompt = self.packages.${final.system}.default;
    };
  };
}
