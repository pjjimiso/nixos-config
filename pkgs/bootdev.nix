{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "bootdev";
  version = "1.24.0";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    hash = lib.fakeHash;
  };

  vendorHash = lib.fakeHash;

  meta = {
    description = "The official Boot.dev CLI client";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
    mainProgram = "bootdev";
  };
}
