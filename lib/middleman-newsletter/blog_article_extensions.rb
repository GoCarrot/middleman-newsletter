module Middleman
  module Blog
    module BlogArticle
      def newsletter_resource=(resource)
        @newsletter_resource = resource
      end

      def newsletter_resource
        @newsletter_resource
      end
    end
  end
end
