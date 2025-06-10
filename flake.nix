# flake.nix
{
   inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
      flake-utils.url = "github:numtide/flake-utils";
   };
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
         packages.${system}.default =
         let
            odin-version = "dev-2025-06";
            hashes = {
               "dev-2025-06" = "sha256-EZT2v1uRQQ5+CxiJaCizf1JtmPbCSsz94JAgJXqhQ6s="; # currently not compiling for me (gb_fprintf_va can never be inlined ...)
               "dev-2025-04" = "sha256-dVC7MgaNdgKy3X9OE5ZcNCPnuDwqXszX9iAoUglfz2k=";
               "dev-2025-03" = "sha256-QmbKbhZglucVpsdlyxJsH2bslhqmd0nuMPC+E0dTpiY=";
            };
         in
         stdenv.mkDerivation {
            name = "odin";
            # src = fetchFromGitHub {
            #    owner = "odin-lang";
            #    repo = "Odin";
            #    rev = odin-version;
            #    hash = hashes.${odin-version};
            # };

            src = fetchzip {
               url = "https://github.com/odin-lang/Odin/releases/download/dev-2025-06/odin-linux-amd64-${odin-version}.zip";
               sha256 = hashes.${odin-version};
            };

            # postPatch = ''
            #    patchShebangs --build build_odin.sh
            #    '';
            #
            # LLVM_CONFIG = lib.getExe' llvmPackages.llvm.dev "llvm-config";
            #
            # dontConfigure = true;
            #
            # buildFlags = [ "release" ];
            #
            nativeBuildInputs = [
               makeBinaryWrapper which gnumake llvmPackages.clang gnutar
            ];

            installPhase = ''
               runHook preInstall

               mkdir -p $out/tmp
               tar -xzf dist.tar.gz -C $out/tmp --strip-components=1

               mkdir -p $out/bin
               cp $out/tmp/odin $out/bin/odin

               mkdir -p $out/share
               cp -r $out/tmp/{base,core,vendor,shared} $out/share
               rm -r $out/tmp

               wrapProgram $out/bin/odin \
               --prefix PATH : ${lib.makeBinPath (with llvmPackages; [
                     bintools
                     llvm
                     clang
                     lld
               ])} \
               --set-default ODIN_ROOT $out/share

               make -C "$out/share/vendor/stb/src"

               make -C "$out/share/vendor/cgltf/src"
               make -C "$out/share/vendor/miniaudio/src/"

               runHook postInstall
               '';
         };
         overlays = {
            default = final: prev: {
               odin = self.packages.${prev.system}.default;
            };
         };
      };
}
