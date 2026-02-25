{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "bootdev";
  version = "1.24.0";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    hash = "sha256-/vVT2daJCxJDmJr9Xi27POCAKURCS171ORb7UJp/CqU=";
  };

  vendorHash = "sha256-ZDioEU5uPCkd+kC83cLlpgzyOsnpj2S7N+lQgsQb8uY=";

  meta = {
    description = "The official Boot.dev CLI client";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
    mainProgram = "bootdev";
  };
}
