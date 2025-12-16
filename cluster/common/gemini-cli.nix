{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "gemini-cli";
  version = "latest";

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    
    # Create a wrapper script that uses npm to install and run gemini-cli
    makeWrapper ${pkgs.nodejs_24}/bin/npx \
      $out/bin/gemini \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs_24 ]} \
      --add-flags "@google/gemini-cli@latest"
  '';

  meta = with pkgs.lib; {
    description = "AI agent that brings the power of Gemini directly into your terminal (npm version)";
    homepage = "https://www.npmjs.com/package/@google/gemini-cli";
  };
}
