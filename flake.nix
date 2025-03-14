# flake.nix
{
   inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
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
            version = "dev-2025-03";
         in
         stdenv.mkDerivation {
            name = "odin";
            src = fetchFromGitHub {
               owner = "odin-lang";
               repo = "Odin";
               rev = version;
               hash = "sha256-QmbKbhZglucVpsdlyxJsH2bslhqmd0nuMPC+E0dTpiY=";
            };

            nativeBuildInputs = [
               makeBinaryWrapper which gnumake
            ];
            postPatch = ''
               substituteInPlace build_odin.sh \
               --replace-fail '-framework System' '-lSystem'
               patchShebangs build_odin.sh
            '';

            LLVM_CONFIG = "${llvmPackages.llvm.dev}/bin/llvm-config";
            dontConfigure = true;
            buildFlags = [
               "release"
            ];

            installPhase = ''
               runHook preInstall

               mkdir -p $out/bin
               cp odin $out/bin/odin

               mkdir -p $out/share
               cp -r {base,core,vendor,shared} $out/share

               wrapProgram $out/bin/odin \
               --prefix PATH : ${lib.makeBinPath (with llvmPackages; [
                     bintools
                     llvm
                     clang
                     lld
               ])} \
               --set-default ODIN_ROOT $out/share

               make -C $out/share/vendor/stb/src

               make -C $out/share/vendor/cgltf/src

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
