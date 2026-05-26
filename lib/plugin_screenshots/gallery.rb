# frozen_string_literal: true

require "erb"

module PluginScreenshots
  # Renders public/index.html: a static gallery listing every plugin
  # subdirectory and its PNGs. Nothing fancy in v0; just scan the
  # filesystem, render a list with thumbnails.
  module Gallery
    module_function

    def render(public_dir)
      plugins = scan(public_dir)
      html = ERB.new(template, trim_mode: "-").result_with_hash(plugins: plugins)
      File.write(File.join(public_dir, "index.html"), html)
    end

    def scan(public_dir)
      Dir.children(public_dir)
        .select { |c| File.directory?(File.join(public_dir, c)) }
        .sort
        .map do |plugin_id|
          shots =
            Dir.glob(File.join(public_dir, plugin_id, "*.png"))
              .sort
              .map { |p| File.basename(p) }
          { id: plugin_id, shots: shots }
        end
    end

    def template
      <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>Discourse plugin screenshots</title>
            <style>
              body { font-family: -apple-system, system-ui, sans-serif; max-width: 1100px; margin: 2rem auto; padding: 0 1rem; color: #222; }
              h1 { font-weight: 600; margin: 0 0 2rem; }
              section { margin-bottom: 3rem; }
              h2 { margin: 0 0 1rem; font-size: 1.2rem; }
              .shots { display: grid; grid-template-columns: repeat(auto-fill, minmax(420px, 1fr)); gap: 1rem; }
              figure { margin: 0; border: 1px solid #ddd; border-radius: 4px; overflow: hidden; }
              figure img { width: 100%; display: block; }
              figcaption { padding: 0.5rem 0.75rem; font-size: 0.9rem; color: #555; background: #fafafa; border-top: 1px solid #eee; }
            </style>
          </head>
          <body>
            <h1>Discourse plugin screenshots</h1>
            <% plugins.each do |plugin| -%>
              <section>
                <h2><%= plugin[:id] %></h2>
                <div class="shots">
                  <% plugin[:shots].each do |shot| -%>
                    <figure>
                      <img src="<%= plugin[:id] %>/<%= shot %>" alt="<%= shot %>">
                      <figcaption><%= shot.sub(/\\.png\\z/, "") %></figcaption>
                    </figure>
                  <% end -%>
                </div>
              </section>
            <% end -%>
          </body>
        </html>
      HTML
    end
  end
end
