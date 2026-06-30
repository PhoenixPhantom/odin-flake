# flake.nix
{
   inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      flake-utils.url = "github:numtide/flake-utils";
   };
   outputs = { self, nixpkgs, flake-utils }:
   flake-utils.lib.eachDefaultSystem (system:
      let
         overlays = [];
         pkgs = import nixpkgs {
            inherit system overlays;
         };
      in
      with pkgs; 
      rec{
         packages.default =
         let
            newestLlvm = llvmPackages_22;
            inherit (newestLlvm) stdenv;
         in
         stdenv.mkDerivation (finalAttrs: {
           pname = "odin";
           version = "nightly-2026-06-30";

           src = fetchFromGitHub {
             owner = "odin-lang";
             repo = "Odin";
             rev = "e276ce552bca8715c80f26f7e3cbdabc0f676b9e";
             hash = "sha256-QYjP+RdES+TrmKSkIDK/r8eGVBgyUu1RMAi9CL4i9wc=";
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

           LLVM_CONFIG = lib.getExe' newestLlvm.llvm.dev "llvm-config";

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
                   with newestLlvm;
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
         devShells.default = pkgs.mkShell {
            name = "odin";
            buildInputs = [ packages.default ];
         };
      }) // {
      overlays = {
         default = final: prev: {
            odin = self.packages.${prev.system}.default;
         };
      };
   };
}

