require "middleman-core"

Middleman::Extensions.register :newsletter do
  require "middleman-newsletter/extension"

  module ::Tilt
    class Mapping
      if !method_defined?(:unregister)
        def unregister(*extensions)
          extensions.each do |ext|
            ext = ext.to_s
            @template_map.delete(ext)
            @lazy_map.delete(ext)
          end

          nil
        end
      end
    end
  end

  ::Middleman::NewsletterExtension
end
