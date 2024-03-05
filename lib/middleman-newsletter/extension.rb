# Require core library
require 'middleman-core'


# Extension namespace
module Middleman
  class NewsletterExtension < ::Middleman::Extension
    extend Forwardable

    # We want this to come after just about everything else, but especially the blog.
    self.resource_list_manipulator_priority = 200

    def_delegator :app, :logger

    option :layout, 'layout', 'Newsletter specific layout'

    def initialize(app, options_hash={}, &block)
      # Call super to build options from the options_hash
      super

      require 'middleman-newsletter/newsletter'
      require 'middleman-newsletter/blog_article_extensions'
      require 'middleman-newsletter/kramdown'

      require 'premailer'
    end

    def after_configuration
      app.sitemap.register_resource_list_manipulator(:newsletter_generator, self)
    end

    def after_build
      @_newsletters.each do |r|
        r.render({}, {})
      end
    end

    def manipulate_resource_list(resources)
      @_newsletters = []
      resources.each do |resource|
        newsletter = convert_to_newsletter(resource)
        next unless newsletter

        @_newsletters << newsletter
      end

      (resources + @_newsletters).uniq
    end

  private

    def convert_to_newsletter(resource)
      return resource if resource.is_a?(Newsletter)
      return nil unless resource.is_a?(::Middleman::Blog::BlogArticle)
      return resource.newsletter_resource if resource.newsletter_resource

      newsletter = ::Middleman::Sitemap::Resource.new(app.sitemap, "newsletters/#{resource.destination_path}", resource.file_descriptor)
      newsletter.extend Newsletter
      newsletter.newsletter_controller = self
      resource.newsletter_resource = newsletter

      newsletter.ignore! if @app.production?

      newsletter
    end
  end
end
