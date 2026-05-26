# frozen_string_literal: true

require "rails_helper"
require "json"

# Capybara system spec that captures one screenshot per URL in a
# plugin's screenshots manifest. Driven by env vars set by the
# orchestrator in lib/plugin_screenshots.rb:
#
#   SCREENSHOTS_PLUGIN_ID  - plugin slug, used as output subdirectory
#   SCREENSHOTS_PLUGIN_DIR - absolute path to the plugin source
#   SCREENSHOTS_OUTPUT_DIR - absolute path to write PNGs into
#   SCREENSHOTS_MANIFEST   - JSON-encoded manifest (urls, optional seed path)
#
# The plugin is expected to be already symlinked into Discourse's
# plugins/ directory; v0 does not handle plugin installation. v0 also
# uses the default theme and a single 1440x900 viewport.
describe "Plugin screenshots", type: :system do
  let(:manifest) { JSON.parse(ENV.fetch("SCREENSHOTS_MANIFEST")) }
  let(:plugin_id) { ENV.fetch("SCREENSHOTS_PLUGIN_ID") }
  let(:plugin_dir) { ENV.fetch("SCREENSHOTS_PLUGIN_DIR") }
  let(:output_dir) { ENV.fetch("SCREENSHOTS_OUTPUT_DIR") }

  before do
    Capybara.current_session.current_window.resize_to(1440, 900)

    if manifest["seed"]
      seed_path = File.join(plugin_dir, manifest["seed"])
      raise "seed file #{seed_path} not found" unless File.exist?(seed_path)
      load seed_path
    end

    sign_in(Discourse.system_user)
  end

  it "captures every configured URL" do
    manifest.fetch("urls").each do |entry|
      path = entry.fetch("path")
      name = entry.fetch("name")

      visit path
      # Give the SPA a moment to settle. Capybara's default wait covers
      # most things but Ember route transitions can be a beat slower
      # than a have_css match would notice. 1 second is the cheap
      # safety margin; if we see flaky shots, swap for an explicit
      # selector wait.
      sleep 1

      file = File.join(output_dir, "#{name}.png")
      page.save_screenshot(file, full: true)
      puts "[plugin-screenshots] wrote #{file}"
    end
  end
end
