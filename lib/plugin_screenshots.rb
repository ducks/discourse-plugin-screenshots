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

  # Returns the on-disk path to the plugin source. For 'local' it's
  # already on the filesystem. For 'git' we clone (or pull) the URL
  # into ./tmp/plugins/<id>/ so subsequent runs in the same workspace
  # are fast.
  def plugin_path(entry)
    source = entry.fetch("source")
    case source.fetch("type")
    when "local"
      source.fetch("path")
    when "git"
      clone_or_update(entry.fetch("id"), source.fetch("url"), source["ref"])
    else
      raise "unsupported plugin source type: #{source["type"].inspect}"
    end
  end

  def clone_or_update(id, url, ref)
    dest = File.expand_path("../tmp/plugins/#{id}", __dir__)
    FileUtils.mkdir_p(File.dirname(dest))

    if Dir.exist?(File.join(dest, ".git"))
      Open3.popen2e("git", "-C", dest, "fetch", "--depth", "1") { |*, w| w.value }
      Open3.popen2e("git", "-C", dest, "reset", "--hard", ref || "FETCH_HEAD") { |*, w| w.value }
    else
      args = ["git", "clone", "--depth", "1"]
      args += ["--branch", ref] if ref
      args += [url, dest]
      Open3.popen2e(*args) { |*, w| w.value }
    end

    dest
  end

  # Reads the plugin's own screenshot manifest.
  def screenshot_config(plugin_dir)
    path = File.join(plugin_dir, "config", "screenshots.yml")
    raise "no #{path}; plugin doesn't opt into screenshots" unless File.exist?(path)
    YAML.load_file(path)
  end

  # Looks up the plugin in config/plugins.yml, resolves its on-disk
  # path (cloning if necessary), and runs the capture. Used by the
  # local CLI workflow.
  def run(plugin_id:)
    entry = plugin_config(plugin_id)
    plugin_dir = plugin_path(entry)
    run_from_path(plugin_id: plugin_id, plugin_dir: plugin_dir)
  end

  # Runs the capture for a plugin whose on-disk path is already known.
  # Used by the reusable GitHub Actions workflow which has already
  # checked out the plugin into a known directory.
  def run_from_path(plugin_id:, plugin_dir:)
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
