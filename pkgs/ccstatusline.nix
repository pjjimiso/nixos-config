{ lib, stdenvNoCC, fetchurl, makeBinaryWrapper, nodejs, git }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ccstatusline";
  version = "2.2.30";

  # The published tarball is four files: LICENSE, README, package.json, and a single
  # ~3MB dist/ccstatusline.js that `bun build --target=node` produced with every
  # dependency inlined (the published package.json has no "dependencies" at all).
  # So there is no node_modules to reproduce, and buildNpmPackage would only buy us
  # an npmDepsHash to keep in sync. fetchurl on the registry tarball is the whole job.
  src = fetchurl {
    url = "https://registry.npmjs.org/ccstatusline/-/ccstatusline-${finalAttrs.version}.tgz";
    # npm publishes dist.integrity in SRI form, which is exactly what fetchurl wants:
    #   curl -s https://registry.npmjs.org/ccstatusline/<version> | jq -r .dist.integrity
    hash = "sha512-5pzYEFjag+oRAI8udChxiN3lKFtzcHhu8KAsEP3T/wU6u3DsT0QJ3fAL2J4Cr+eo9AqRalqvP4sYpDguzn/1HQ==";
  };

  nativeBuildInputs = [ makeBinaryWrapper ];

  dontBuild = true;

  # Claude Code re-runs the status line command on every repaint, so the wrapper is on
  # a hot path: makeBinaryWrapper execs node directly instead of forking a shell first.
  installPhase = ''
    runHook preInstall

    install -Dm644 dist/ccstatusline.js $out/lib/ccstatusline/ccstatusline.js
    install -Dm644 package.json $out/lib/ccstatusline/package.json

    makeBinaryWrapper ${lib.getExe nodejs} $out/bin/ccstatusline \
      --add-flags $out/lib/ccstatusline/ccstatusline.js \
      --suffix PATH : ${lib.makeBinPath [ git ]}

    runHook postInstall
  '';

  meta = {
    description = "Customizable status line formatter for the Claude Code CLI";
    homepage = "https://github.com/sirmalloc/ccstatusline";
    license = lib.licenses.mit;
    mainProgram = "ccstatusline";
    platforms = lib.platforms.all;
  };
})
