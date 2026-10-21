{ lib, stdenvNoCC, fetchurl, patchelf, makeBinaryWrapper, glibc, ripgrep }:

# opencode 2.x. The v2 line is published under a new npm scope (@opencode/cli;
# @opencode-ai/cli was the pre-release beta) rather than nixpkgs' opencode-ai.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "2.0.32";

  # The @opencode/cli wrapper package only selects a platform package via
  # optionalDependencies; the platform package is just package.json plus a single
  # `bun build --compile` executable, so fetch that directly.
  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${finalAttrs.version}.tgz";
    #   curl -s https://registry.npmjs.org/@opencode/cli-linux-x64/<version> | jq -r .dist.integrity
    hash = "sha512-Q50ofBQ3gdwjD6ZQhrVR8fVlm8D2xPMshy4dynY6l6b+qLdKgBSJ9WpoaDyrQX1YWmf2s7IN4RbXmoXXdJitDA==";
  };

  nativeBuildInputs = [ patchelf makeBinaryWrapper ];

  dontBuild = true;
  # Stripping would discard the bun payload appended to the executable.
  dontStrip = true;
  dontPatchELF = true;

  # The binary only needs glibc, so swapping /lib64/ld-linux-x86-64.so.2 for the store
  # loader is enough; no autoPatchelfHook/RPATH work. It can't be launched through
  # `ld.so <binary>` instead, because bun locates its embedded payload via /proc/self/exe.
  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode $out/libexec/opencode/opencode
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 \
      $out/libexec/opencode/opencode

    # v2's default database is ~/.local/share/opencode/opencode.db, but that file is a
    # stale one an older v1 left behind (v1's real sessions are in opencode-stable.db).
    # v2 was trialled side by side with v1 pointed at opencode2.db, so keep it there:
    # that preserves the trial's sessions and leaves both v1 files untouched. A bare
    # filename resolves inside the data dir.
    makeBinaryWrapper $out/libexec/opencode/opencode $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set OPENCODE_DISABLE_AUTOUPDATE true \
      --set-default OPENCODE_DB opencode2.db

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "x86_64-linux" ];
  };
})
