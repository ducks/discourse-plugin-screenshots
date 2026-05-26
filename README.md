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

## License

MIT.
