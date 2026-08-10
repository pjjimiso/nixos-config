{ lib, buildGoModule, coreutils, src }:

buildGoModule {
  pname = "bootdev";
  version = "unstable";
  inherit src;

  vendorHash = "sha256-ZDioEU5uPCkd+kC83cLlpgzyOsnpj2S7N+lQgsQb8uY=";

  # The timeout test spawns a fake `go` that execs /bin/sleep, which the nix build
  # sandbox does not provide (only /bin/sh exists)
  # Replace /bin/sleep with nix store's ${coreutils}/bin/sleep to make it work in the sandbox
  postPatch = ''
    substituteInPlace version/version_test.go \
      --replace-fail "exec /bin/sleep 5" "exec ${coreutils}/bin/sleep 5"
  '';

  meta = {
    description = "The official Boot.dev CLI client";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
    mainProgram = "bootdev";
  };
}
