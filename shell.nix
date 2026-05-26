{ pkgs ? import <nixpkgs> {} }:

# Provides a NixOS-compatible Playwright Chromium build via nixpkgs'
# playwright-driver package, which pre-patches the browser with the
# right RPATHs. Layered on top of discourse-app.nix (Ruby, Node,
# Postgres, Redis) by using shell-within-shell:
#
#   nix-shell ~/discourse/nix-shells/discourse-app.nix --run \
#     "nix-shell ~/dev/discourse-plugin-screenshots/shell.nix --run \
#       'cd ~/dev/discourse-plugin-screenshots && bin/screenshot-plugins --plugin discourse-itinerary'"
#
# Sets PLAYWRIGHT_BROWSERS_PATH so the Playwright ruby client picks up
# the nixpkgs-provided browser instead of the generic Linux build it
# downloads to ~/.cache/ms-playwright (which won't run on NixOS).
#
# PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 keeps `pnpm playwright-install`
# from re-downloading the broken binary on subsequent runs.

pkgs.mkShell {
  buildInputs = [ pkgs.playwright-driver.browsers ];

  shellHook = ''
    export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    export PLAYWRIGHT_NODEJS_PATH="${pkgs.nodejs}/bin/node"

    echo "discourse-plugin-screenshots:"
    echo "  PLAYWRIGHT_BROWSERS_PATH=$PLAYWRIGHT_BROWSERS_PATH"
    echo "  Set DISCOURSE_PATH if your checkout isn't at ~/discourse/discourse."
  '';
}
