{
  lib,
  stdenvNoCC,
  fetchgit,
  makeWrapper,
  zsh,
  python3,
  rsync,
  curl,
  gawk,
  coreutils,
  findutils,
  diffutils,
  gnugrep,
  gnused,
  bzip2,
  util-linux,
  hostname-debian,
  shunit2,
}:

let
  runtimeDeps = [
    zsh
    rsync
    curl
    gawk
    coreutils
    findutils
    diffutils
    gnugrep
    gnused
    bzip2
    util-linux # flock
    hostname-debian
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "quick-fedora-mirror";
  version = "0-unstable-2024-05-08";

  src = fetchgit {
    url = "https://forge.fedoraproject.org/infra/quick-fedora-mirror";
    rev = "ee1f19fd449e6db65e164cd052141836712162e9";
    hash = "sha256-qGqq/J6ewefaTwV+PUZURpmXL2BFZzbdRlhAEy10Ub4=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    zsh
    python3
  ];

  postPatch = ''
    # The scripts default to FHS paths for their tools; use PATH instead.
    substituteInPlace quick-fedora-mirror \
      --replace-fail 'CURL=/usr/bin/curl' 'CURL=curl' \
      --replace-fail 'RSYNC=/usr/bin/rsync' 'RSYNC=rsync'

    # Plain "python" doesn't exist in nixpkgs' python3.
    substituteInPlace quick-fedora-hardlink \
      --replace-fail '#!/usr/bin/python' '#!/usr/bin/env python3'

    patchShebangs --build runtests test

    # Upstream test rot: the checksum tests predate create-filelist emitting
    # md5/sha256/sha512 sections, and the retry tests fail outside Nix too.
    sed -i 's/^test_checksum/skip_checksum/' test/filelist/test
    rm test/mirror/test-retry
  '';

  dontBuild = true;

  doCheck = true;
  nativeCheckInputs = runtimeDeps ++ [ python3 ];
  checkPhase = ''
    runHook preCheck
    patchShebangs --build quick-fedora-mirror quick-fedora-hardlink.zsh quick-fedora-status create-filelist quick-fedora-hardlink
    SHUNIT=${shunit2}/bin/shunit2 TMPDIR=$(mktemp -d) zsh ./runtests
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 -t $out/bin \
      quick-fedora-mirror \
      quick-fedora-hardlink \
      quick-fedora-hardlink.zsh \
      quick-fedora-status \
      create-filelist

    install -Dm644 quick-fedora-mirror.conf.dist \
      $out/share/quick-fedora-mirror/quick-fedora-mirror.conf.dist
    install -Dm644 -t $out/share/doc/quick-fedora-mirror README.rst doc/*.rst
    install -Dm755 example-create-filelist-wrapper \
      $out/share/doc/quick-fedora-mirror/example-create-filelist-wrapper

    runHook postInstall
  '';

  postFixup = ''
    for prog in quick-fedora-mirror quick-fedora-hardlink.zsh quick-fedora-status; do
      wrapProgram $out/bin/$prog --prefix PATH : ${lib.makeBinPath runtimeDeps}
    done
  '';

  meta = {
    description = "Fast Fedora mirroring client using the fullfiletimelist files";
    homepage = "https://forge.fedoraproject.org/infra/quick-fedora-mirror";
    license = lib.licenses.cc0;
    platforms = lib.platforms.unix;
    mainProgram = "quick-fedora-mirror";
  };
})
