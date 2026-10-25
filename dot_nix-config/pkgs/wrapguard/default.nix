# Not in nixpkgs; carries a local patch (./ipv6-endpoints.patch) for profiles
# with multiple interface addresses.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  gcc,
}:

buildGoModule rec {
  pname = "wrapguard";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "puzed";
    repo = "wrapguard";
    rev = "v${version}";
    hash = "sha256-OcS0Lk2SIkHot0pVgj/VOI4srBHhckRLF+uNEeQTYeE=";
  };

  vendorHash = "sha256-ssWSvgtgmpeQ6X28Z31x1YsN1G7NRHhm8Cfmzs233Rc=";

  nativeBuildInputs = [ gcc ];

  patches = [ ./ipv6-endpoints.patch ];

  postInstall = ''
    $CC -shared -fPIC -Wall -Wextra -Wpedantic -O2 lib/intercept.c -ldl \
      -o "$out/bin/libwrapguard.so"
  '';

  doCheck = false; # test suite needs a live tunnel

  meta = {
    description = "Userspace WireGuard proxy for transparent network tunneling";
    homepage = "https://github.com/puzed/wrapguard";
    license = lib.licenses.mit;
    mainProgram = "wrapguard";
  };
}
