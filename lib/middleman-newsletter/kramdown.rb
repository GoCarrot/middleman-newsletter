# frozen_string_literal: true

module Middleman
  module Renderers
    class KramdownEmailTemplate < ::Tilt::KramdownTemplate
      def initialize(*args, &block)
        super

        @context = @options[:context] if @options.key?(:context)
      end

      def evaluate(context, *)
        MiddlemanKramdownEmailHtmlConverter.scope = @context || context

        @output ||= begin
          output, warnings = MiddlemanKramdownEmailHtmlConverter.convert(@engine.root, @engine.options)
          @engine.warnings.concat(warnings)
          output
        end
      end
    end

    class MiddlemanKramdownEmailHtmlConverter < ::Kramdown::Converter::Html
      cattr_accessor :scope

      BLANK_LINE = %(<div class="paragraph-break"><br></div>)
      TABLE_PREAMBLE = %(<table class="module" role="module" data-type="text" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td><div>)
      TABLE_POSTFIX = %(<br></div>#{BLANK_LINE}</td></tr></tbody></table>)
      def convert_p(el, indent)
        if el.options[:transparent]
          inner(el, indent)
        elsif el.children.size == 1 && el.children.first.type == :img
          convert_standalone_image(el, indent)
        else
          "#{(' ' * indent)}#{TABLE_PREAMBLE}#{format_as_block_html("span", el.attr, inner(el, indent), indent)}#{TABLE_POSTFIX}"
        end
      end


      IMG_TABLE_PREFIX = %(<table class="module" role="module" data-type="image" border="0" cellpadding="0" cellspacing="0" width="100%"><tbody><tr><td>)
      IMG_TABLE_POSTFIX = %(#{BLANK_LINE}</td></tr></tbody></table>)
      def convert_standalone_image(el, indent)
        image = el.children.first
        "#{(' ' * indent)}#{IMG_TABLE_PREFIX}#{convert_img(image, indent)}#{IMG_TABLE_POSTFIX}"
      end

      def convert_img(el, indent)
        attr = el.attr.dup
        attr['class'] = ["max-width", *attr['class']].compact.join(' ')
        link = attr.delete('src')
        # Attempt to manually run the asset host extension, since it's dependent on pulling data
        # from Rack normally, and we're directly rendering our content.
        if scope.extensions[:asset_host]
          uri = ::Middleman::Util.parse_uri(link)
          if uri.relative? && uri.host.nil?
            link = scope.extensions[:asset_host].rewrite_url(link, ::Pathname.new('/'), '')
          end
        end
        scope.image_tag(link, attr)
      end

      def convert_br(_el, _indent)
        if @stack.last&.type == :p
          "</span></div>\n<div><span>"
        else
          ''
        end
      end

      def convert_table(el, indent)
        if el.type == :table
          attr = el.attr.dup
          attr['class'] = ['module', *attr['class']].compact.join(' ')
          attr['data-type'] = 'table'
          format_as_indented_block_html(el.type, attr, inner(el, indent), indent) + '<br>'
        else
          super(el, indent)
        end
      end

      TD_TABLE_PREFIX = %(<table cellpadding="0" cellspacing="0" align="left" border="0" bgcolor=""><tbody><tr>)
      TD_TABLE_POSTFIX = %(</tr></tbody></table>)

      def convert_thead(el, indent)
        format_as_block_html(:tr, el.attr, inner(el, indent), indent)
      end

      def convert_td(el, indent)
        res = inner(el, indent)
        type = :td

        count = @stack.last.children.length
        width = (90.0 / count).to_s
        width = '%.1f%%' % width

        attr = el.attr.dup
        alignment = @stack[-3].options[:alignment][@stack.last.children.index(el)]

        if alignment != :default
          attr['style'] = (attr.key?('style') ? "#{attr['style']}; " : '') + "text-align: #{alignment}"
        end
        attr['style'] = (attr.key?('style') ? "#{attr['style']}; " : '') + "width: #{width}"

        res = "<table><tbody><tr><td>#{res}</td></tr></tbody></table>"

        format_as_block_html(:td, attr, res.empty? ? entity_to_str(ENTITY_NBSP) : res, indent)
      end
    end
  end
end
