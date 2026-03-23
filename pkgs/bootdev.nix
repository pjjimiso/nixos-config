{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "bootdev";
  version = "1.27.4";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    hash = "sha256-9avSkYxXqwaLCJeNTJJG8biEVUwZVYRauZclw8wbd50=";
  };

  vendorHash = "sha256-ZDioEU5uPCkd+kC83cLlpgzyOsnpj2S7N+lQgsQb8uY=";

  meta = {
    description = "The official Boot.dev CLI client";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
    mainProgram = "bootdev";
  };
}
