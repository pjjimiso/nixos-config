{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "bootdev";
  version = "1.26.0";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    hash = "sha256-hr8mqnX4mv6P8WpXCpP678lLUaanUu6X4jL5GJeBdzo=";
  };

  vendorHash = "sha256-ZDioEU5uPCkd+kC83cLlpgzyOsnpj2S7N+lQgsQb8uY=";

  meta = {
    description = "The official Boot.dev CLI client";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
    mainProgram = "bootdev";
  };
}
