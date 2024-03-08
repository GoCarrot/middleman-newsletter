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
    option :sendgrid_api_key, nil, 'API Key for SendGrid -- must have marketing access.'
    option :sendgrid_category, 'newsletters', 'Category assigned to all managed single sends in SendGrid.'
    option :subject_line, proc { |newsletter| newsletter.source_resource.title }, 'A proc that takes the newsletter resource and returns the subject line for the email. Defaults to the source blog post title.'
    option :preview_text, proc { |newsletter| newsletter.source_resource.data.description }, 'A proc that takes the newsletter resource and returns preview text for the email. Defaults to the source blog post description.'
    option :content_modifier, proc { |_newsletter, content| content }, 'A proc that takes the newsletter resource and rendered HTML for the newsletter and can return modified content.'

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
      if options.sendgrid_api_key.blank?
        logger.info('== Newsletter: No SendGrid API key, not setting up newsletters')
        return
      end

      require 'sendgrid-ruby'

      expected_newsletters = @_newsletters.each_with_object({}) { |r, h| h[r.source_resource.title] = r unless r.source_resource.data['publish_newsletter'] == false }
      live_newsletters = extant_newsletters.each_with_object({}) { |r, h| h[r[:name]] = r }

      to_update = []
      to_create = []

      expected_newsletters.each do |(key, value)|
        live = live_newsletters[key]
        if live
          to_update << [live[:id], value] if live[:status] != 'triggered'
        else
          to_create << value
        end
      end

      to_destroy = live_newsletters.each_with_object([]) { |(key, value), arr| arr << value if !expected_newsletters.key?(key) && value[:status] != 'triggered' }

      to_create.each do |newsletter|
        create_in_sendgrid(newsletter)
      end

      to_update.each do |(id, newsletter)|
        update_in_sendgrid(id, newsletter)
      end

      to_destroy.each do |live|
        destroy_in_sendgrid(live)
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

    def render_newsletter(newsletter)
      newsletter.render({}, {})
    end

    def sendgrid_client
      @sendgrid_client ||= SendGrid::API.new(api_key: options.sendgrid_api_key).client
    end

    def create_in_sendgrid(newsletter)
      blog = newsletter.source_resource
      name = blog.title
      logger.info("== Creating Single Send for #{name}")
      sendgrid_client.marketing.singlesends.post(
        request_body: {
          name: name,
          categories: [options.sendgrid_category],
          email_config: {
            subject: options.subject_line.call(newsletter),
            html_content: render_newsletter(newsletter)
          }
        }
      )
    end

    def update_in_sendgrid(singlesend_id, newsletter)
      blog = newsletter.source_resource
      name = blog.title
      logger.info("== Updating Single Send for #{name}, sg id #{singlesend_id}")
      sendgrid_client.marketing.singlesends._(singlesend_id).patch(
        request_body: {
          email_config: {
            subject: options.subject_line.call(newsletter),
            html_content: render_newsletter(newsletter)
          }
        }
      )
    end

    def destroy_in_sendgrid(singlesend)
      id = singlesend[:id]
      logger.info("== Destroying Single Send #{singlesend[:name]}, sg id #{id}")
      sendgrid_client.marketing.singlesends._(id).delete()
    end

    def extant_newsletters
      @extant_newsletters ||= begin
        response = sendgrid_client.marketing.singlesends.search.post(
          request_body: {
            categories: [options.sendgrid_category]
          }
        )
        # I decided to include an extra sanity check where we strip out any single sends that don't have
        # our tag category before any further consideration. In theory the API should not return any single sends
        # that don't have our category, buuuut since we will go on to delete 'unexpected' singlesends...
        # This sanity check will help us not go "sorcerer's apprentice" if the SendGrid API fails.
        capture_all(response).select { |result| result[:categories].include?(options.sendgrid_category) }
      end
    end

    def capture_all(response)
      ret = response.parsed_body[:result]
      next_page = response.parsed_body.dig(:_metadata, :next)
      return ret if next_page.nil?
      next_response = sendgrid_client._(next_page.delete_prefix(sendgrid_client.host)).post()
      ret + capture_all(next_response)
    end

    def convert_to_newsletter(resource)
      return resource if resource.is_a?(Newsletter)
      return nil unless resource.is_a?(::Middleman::Blog::BlogArticle)
      return resource.newsletter_resource if resource.newsletter_resource

      newsletter = ::Middleman::Sitemap::Resource.new(app.sitemap, "newsletters/#{resource.destination_path}", resource.file_descriptor)
      newsletter.extend Newsletter
      newsletter.newsletter_controller = self
      resource.newsletter_resource = newsletter
      newsletter.source_resource = resource

      newsletter.ignore! if @app.production?

      newsletter
    end
  end
end
