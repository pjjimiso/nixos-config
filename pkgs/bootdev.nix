{ lib, buildGoModule, src }:

buildGoModule {
  pname = "bootdev";
  version = "unstable";
  inherit src;

  vendorHash = "sha256-ZDioEU5uPCkd+kC83cLlpgzyOsnpj2S7N+lQgsQb8uY=";

  meta = {
    description = "The official Boot.dev CLI client";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
    mainProgram = "bootdev";
  };
}
