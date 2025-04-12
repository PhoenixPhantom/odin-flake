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
            odin-version = "dev-2025-04";
            hashes = {
               "dev-2025-04" = "sha256-hdl9i/Zyto+WDQLfdAOmrdE4BKX8rM/+e6Ta3jsFgxg=";
               "dev-2025-03" = "sha256-QmbKbhZglucVpsdlyxJsH2bslhqmd0nuMPC+E0dTpiY=";
            };
         in
         stdenv.mkDerivation {
            name = "odin";
            src = fetchFromGitHub {
               owner = "odin-lang";
               repo = "Odin";
               rev = odin-version;
               hash = hashes.${odin-version};
            };

            nativeBuildInputs = [
               makeBinaryWrapper which gnumake llvmPackages.clang
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
