# frozen_string_literal: true

require "yaml"
require "fileutils"
require "open3"

# Orchestrates a screenshot run.
#
# Reads config/plugins.yml from this repo, finds each plugin's local
# path, reads the plugin's own config/screenshots.yml, then drives
# Discourse's test environment to capture the configured URLs.
#
# v0 assumes:
#   - A Discourse checkout at DISCOURSE_PATH (default ~/discourse/discourse)
#   - The plugin is symlinked into Discourse's plugins/ directory
#   - Default theme, 1440x900 viewport
#
# v0 captures one plugin at a time; multi-plugin orchestration lands
# once the loop is closed on the single case.
module PluginScreenshots
  CONFIG_PATH = File.expand_path("../config/plugins.yml", __dir__)
  PUBLIC_DIR = File.expand_path("../public", __dir__)

  module_function

  def discourse_path
    ENV.fetch("DISCOURSE_PATH", File.expand_path("~/discourse/discourse"))
  end

  def plugin_config(plugin_id)
    config = YAML.load_file(CONFIG_PATH)
    entry = config.fetch("plugins").find { |p| p["id"] == plugin_id }
    raise "plugin '#{plugin_id}' not in #{CONFIG_PATH}" unless entry
    entry
  end

  def plugin_path(entry)
    source = entry.fetch("source")
    case source.fetch("type")
    when "local"
      source.fetch("path")
    else
      raise "v0 only supports local source; got #{source["type"].inspect}"
    end
  end

  # Reads the plugin's own screenshot manifest.
  def screenshot_config(plugin_dir)
    path = File.join(plugin_dir, "config", "screenshots.yml")
    raise "no #{path}; plugin doesn't opt into screenshots" unless File.exist?(path)
    YAML.load_file(path)
  end

  # Runs the capture system spec inside the Discourse repo. Passes the
  # plugin + manifest path through env vars so the spec knows what to
  # do; the spec lives in this repo and gets symlinked into Discourse
  # for the run.
  def run(plugin_id:)
    entry = plugin_config(plugin_id)
    plugin_dir = plugin_path(entry)
    manifest = screenshot_config(plugin_dir)

    output_dir = File.join(PUBLIC_DIR, plugin_id)
    FileUtils.mkdir_p(output_dir)

    spec_path = File.expand_path("../spec/system/plugin_screenshots_spec.rb", __dir__)

    env = {
      "SCREENSHOTS_PLUGIN_ID" => plugin_id,
      "SCREENSHOTS_PLUGIN_DIR" => plugin_dir,
      "SCREENSHOTS_OUTPUT_DIR" => output_dir,
      "SCREENSHOTS_MANIFEST" => JSON.dump(manifest),
      "RAILS_ENV" => "test",
    }

    cmd = ["bin/rspec", spec_path]
    puts "[plugin-screenshots] running: #{cmd.join(" ")}"
    puts "[plugin-screenshots] plugin: #{plugin_id} at #{plugin_dir}"

    Dir.chdir(discourse_path) do
      Open3.popen2e(env, *cmd) do |_stdin, stdout_err, wait|
        stdout_err.each_line { |l| puts l }
        status = wait.value
        raise "rspec exited #{status.exitstatus}" unless status.success?
      end
    end

    render_gallery
    output_dir
  end

  def render_gallery
    require_relative "plugin_screenshots/gallery"
    Gallery.render(PUBLIC_DIR)
  end
end

require "json"
