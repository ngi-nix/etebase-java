{
  description = "A Java/Android library for Etebase";
  
  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-21.04";
  
  outputs = { self, nixpkgs }:
    let
      
      # Generate a user-friendly version number.
      version = builtins.substring 0 8 self.lastModifiedDate;
      
      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      
      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      
      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
      
    in
      
      {
        
        # A Nixpkgs overlay.
        overlay = final: prev: {
          
          etebase-java = with final; stdenv.mkDerivation rec {
            name = "etebase-java-${version}";
            
            src = ./.;
            
            cargoDeps = rustPLatform.fetCargoTarball {
              inherit src;
              hash = lib.fakeSha256;
            };
            
            buildInputs = [ openssl ];
            
            nativeBuildInputs = [
              pkg-config
            ] ++ (with rustPlatform; [
              cargoSetupHook
              rust.cargo
              rust.rustc
            ]);
            
          };
          
        };
        
        # Provide some binary packages for selected system types.
        packages = forAllSystems (system:
          {
            inherit (nixpkgsFor.${system}) etebase-java;
          });
        
        # The default package for 'nix build'. This makes sense if the
        # flake provides only one package or there is a clear "main"
        # package.
        defaultPackage = forAllSystems (system: self.packages.${system}.etebase-java);
        
      };
}
