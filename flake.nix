{
  description = "A Java/Android library for Etebase";
  
  inputs = {
    nixpkgs.url = "github:Nixos/nixpkgs/nixos-21.05";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };
  
  outputs = { self, nixpkgs, rust-overlay }:
    let
      
      # Generate a user-friendly version number.
      version = builtins.substring 0 8 self.lastModifiedDate;
      
      # System types to support.
      supportedSystems = [ "x86_64-linux" ];
      
      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      
      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay rust-overlay.overlay ]; });

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          android_sdk.accept_license = true;
        };
      };

      androidComposition = pkgs.androidenv.composeAndroidPackages { includeNDK = true; };
      ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
      ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";
      
    in
      
      {
        
        # A Nixpkgs overlay.
        overlay = final: prev: {
          
          etebase-java = with final; stdenv.mkDerivation rec {
            name = "etebase-java-${version}";
            
            src = ./.;
            
            cargoDeps = rustPlatform.fetchCargoTarball {
              inherit src;
              hash = "sha256-mvCjK9jPcGCMmuwa1e2QFd+c7ak17NdxP5LkRGWc9as=";
            };
            
            rust-bin' = rust-bin.nightly.latest.default.override {
                targets = [ "aarch64-linux-android" "armv7-linux-androideabi" "i686-linux-android" "x86_64-linux-android" ];
            };

            buildInputs = [ openssl ];
            
            nativeBuildInputs = [
              pkg-config
            ] ++ (with rustPlatform; [
              cargoSetupHook
              rust.cargo
              rust-bin'
              rustup
            ]);

            buildPhase = ''
               export PATH="$PATH:/${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/";
               bash ./build.sh;
            '';
            
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