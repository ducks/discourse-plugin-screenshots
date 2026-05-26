# discourse-plugin-screenshots

A tool for capturing screenshots of Discourse plugin UIs against a real
Discourse instance, on a schedule, with a published gallery. Modeled on
[discourse-theme-screenshots](https://github.com/pmusaraj/discourse-theme-screenshots)
but pointed at plugin routes rather than theme rendering.

## Status

Very early. v0 captures one plugin (discourse-itinerary), at one theme
(default), at one viewport (1440x900). Iteratively pushing toward
multi-plugin / multi-theme / CI from there.

## Plugin contract

A plugin opts in by shipping `config/screenshots.yml` at the top of its
repo:

```yaml
# Optional Ruby file run inside the Rails test env before captures.
# Use it to seed plugin-specific data so /your-plugin renders something
# realistic rather than the empty state.
seed: spec/screenshot_seed.rb

# URLs to capture. The screenshot file becomes <name>.png.
urls:
  - path: /itinerary
    name: trip-list
    description: Trip list home page
  - path: /itinerary/2
    name: timeline
    description: Per-trip timeline with day grouping
```

Plugins without `screenshots.yml` are skipped.

## Local usage

Requires a Discourse checkout at `~/discourse/discourse` and the plugin
symlinked into `~/discourse/discourse/plugins/`.

```sh
bin/screenshot-plugins --plugin discourse-itinerary
```

Output lands in `public/<plugin>/<name>.png` plus a static gallery
`public/index.html`.

On NixOS you'll need a shell layered with the right Chromium runtime
deps:

```sh
nix-shell ~/discourse/nix-shells/discourse-app.nix --run \
  "nix-shell ~/dev/discourse-plugin-screenshots/shell.nix --run \
    'bin/screenshot-plugins --plugin discourse-itinerary'"
```

## CI

The workflow at `.github/workflows/plugin-screenshots.yml` is a
**reusable GitHub Actions workflow**. Plugin repos opt in by adding
a small workflow file of their own that delegates to it.

Plugin's `.github/workflows/screenshots.yml`:

```yaml
name: Screenshots
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  screenshots:
    uses: ducks/discourse-plugin-screenshots/.github/workflows/plugin-screenshots.yml@main
```

What the reusable workflow does, running inside Discourse's official
test container so Playwright's Chromium has the system libs it needs:

1. Checks out the calling plugin, this tool, and `discourse/discourse`
2. Symlinks the plugin into `discourse/plugins/<id>`
3. Boots the Discourse test env (Postgres + Redis + migrations)
4. Reads the plugin's `config/screenshots.yml` for URLs and seed file
5. Runs the seed, captures each URL, writes PNGs to `public/<id>/`
6. Publishes `public/` to the calling plugin's GitHub Pages

Each plugin maintainer owns their schedule, their gallery, and their
CI minutes. The tool repo doesn't enumerate plugins.

## config/plugins.yml (local only)

For local development the tool reads `config/plugins.yml` to find a
plugin's source path. This file is **not used by CI** - it exists so
you can run captures against a plugin you're hacking on without
committing anything.

```yaml
plugins:
  - id: discourse-itinerary
    name: Itinerary
    source:
      type: local
      path: /home/me/dev/discourse-itinerary
```

`type: git` works too (clones on demand) but the reusable workflow
already handles cloning for CI, so `git` is mainly useful for
clean-room local runs of a plugin you haven't checked out.

## License

MIT.
