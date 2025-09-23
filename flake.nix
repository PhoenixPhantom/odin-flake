# flake.nix
{
   inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
      flake-utils.url = "github:numtide/flake-utils";
   };
   # until odin reliably builds again
   outputs = { self, nixpkgs, flake-utils }:
      let
         overlays = [];
         system = "x86_64-linux";
         pkgs = import nixpkgs {
            inherit system overlays;
         };
      in
      with pkgs;
      {
         overlays = {
            default = final: prev: {
               odin = self.packages.${prev.system}.default;
            };
         };

         packages.${system}.default =
         let
            inherit (llvmPackages) stdenv;
         in
         stdenv.mkDerivation (finalAttrs: {
           pname = "odin";
           version = "dev-2025-09";

           src = fetchFromGitHub {
             owner = "odin-lang";
             repo = "Odin";
             tag = finalAttrs.version;
             hash = "sha256-PxegNMEzxytZtmhmzDgb1Umzx/9aUIlc9SDojRlZfsE=";
           };

            # see the official package on https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/od/odin/package.nix#L90
           patches = [
             ./darwin-remove-impure-links.patch
             ./system-raylib.patch
           ];

           postPatch = ''
             substituteInPlace src/build_settings.cpp \
               --replace-fail "arm64-apple-macosx" "arm64-apple-darwin"

             rm -r vendor/raylib/{linux,macos,macos-arm64,wasm,windows}

             patchShebangs --build build_odin.sh
           '';

           LLVM_CONFIG = lib.getExe' llvmPackages.llvm.dev "llvm-config";

           dontConfigure = true;

           buildFlags = [ "release" ];

           nativeBuildInputs = [
             makeBinaryWrapper
             which
           ];

           installPhase = ''
             runHook preInstall

             mkdir -p $out/bin
             cp odin $out/bin/odin

             mkdir -p $out/share
             cp -r {base,core,vendor,shared} $out/share

             wrapProgram $out/bin/odin \
               --prefix PATH : ${
                 lib.makeBinPath (
                   with llvmPackages;
                   [
                     bintools
                     llvm
                     clang
                     lld
                   ]
                 )
               } \
               --set-default ODIN_ROOT $out/share

             make -C "$out/share/vendor/cgltf/src/"
             make -C "$out/share/vendor/stb/src/"
             make -C "$out/share/vendor/miniaudio/src/"

             runHook postInstall
           '';

           passthru.updateScript = nix-update-script { };

           meta = {
             description = "Fast, concise, readable, pragmatic and open sourced programming language";
             downloadPage = "https://github.com/odin-lang/Odin";
             homepage = "https://odin-lang.org/";
             changelog = "https://github.com/odin-lang/Odin/releases/tag/${finalAttrs.version}";
             license = lib.licenses.bsd3;
             mainProgram = "odin";
             platforms = lib.platforms.unix;
             broken = stdenv.hostPlatform.isMusl;
           };
         });
      };
}
