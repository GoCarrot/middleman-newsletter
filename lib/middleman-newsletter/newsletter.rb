module Middleman
  module Newsletter
    def self.extended(base)
      base.class.send(:attr_accessor, :newsletter_controller)
    end

    def newsletter_options
      newsletter_controller.options
    end

    def render(opts = {}, locs = {}, &block)
      # Ensure we render using our custom email renderer
      ::Tilt.register(source_file.downcase, ::Middleman::Renderers::KramdownEmailTemplate)

      unless opts.key?(:layout)
        opts[:layout] = metadata[:options][:newsletter_layout]
        opts[:layout] = newsletter_options.layout if opts[:layout].nil? || opts[:layout] == :_auto_layout

        # Convert to a string unless it's a boolean
        opts[:layout] = opts[:layout].to_s if opts[:layout].is_a? Symbol
      end

      content = super(opts, locs, &block)
      Premailer.new(content, with_html_string: true, output_encoding: 'UTF-8', input_encoding: 'UTF-8').to_inline_css
    ensure
      # Don't pollute the tilt mappings, will slow things down
      ::Tilt.default_mapping.unregister(source_file.downcase)
    end
  end
end
