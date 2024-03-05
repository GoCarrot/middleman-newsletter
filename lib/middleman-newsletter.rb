require "middleman-core"

Middleman::Extensions.register :newsletter do
  require "middleman-newsletter/extension"

  module ::Tilt
    class Mapping
      # This was added in Tilt 2.1, but middleman-core is tied to ~> 2.0.9.
      # So, backport, but guard it in case middleman-core updates to permit
      # more modern tilt versions.
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
