# typed: false
# frozen_string_literal: true

module DynamicRendering
  module ActsAsDynamicallyRenderable
    extend ActiveSupport::Concern

    USE_DYNAMIC_RENDERING_FOR_USER_AGENTS = /(googlebot|google-structured-data-testing-tool|bingbot)/i
    MOBILE_USER_AGENT = /mobile/i
    MOBILE_VIEWPORT = { width: 410, height: 730 }
    DESKTOP_VIEWPORT = { width: 1400, height: 950 }

    included do
      def render_dynamically(log_level: :info)
        return unless request_suitable_for_dynamic_rendering? && response_suitable_for_dynamic_rendering?

        Rails.logger.public_send(
          log_level,
          <<~TEXT
            [Dynamic rendering 🔍 ]:
            • URL: #{request.original_url}"
            • User-Agent: #{request.user_agent}
            • Viewport: #{dynamic_rendering_viewport.inspect}
          TEXT
        )

        response.body = HtmlRenderer.new(
          response.body,
          dynamic_rendering_viewport,
          request.original_url
        ).to_s
      end
    end

    class_methods do
      def enable_dynamic_rendering(arguments = {})
        append_after_action(:render_dynamically, **arguments)
      end
    end

    private

    def request_suitable_for_dynamic_rendering?
      USE_DYNAMIC_RENDERING_FOR_USER_AGENTS.match?(request.user_agent)
    end

    def dynamic_rendering_viewport
      return MOBILE_VIEWPORT if dynamic_rendering_request_from_mobile_crawler?

      DESKTOP_VIEWPORT
    end

    def dynamic_rendering_request_from_mobile_crawler?
      MOBILE_USER_AGENT.match?(request.user_agent)
    end

    def response_suitable_for_dynamic_rendering?
      response.ok? &&
        Mime::Type.lookup(response.media_type).html?
    end

    class HtmlRenderer
      DEFAULT_OPTIONS = { 'waitUntil' => 'networkidle2' }

      def initialize(original_response_body, viewport, original_url, options = DEFAULT_OPTIONS)
        @original_response_body = original_response_body
        @viewport = viewport
        @original_url = original_url
        @options = options
      end

      def to_s
        HtmlPostProcessor.new(rendered_html).to_s
      end

      private

      def rendered_html
        processor.convert(
          'content',
          response_body_for_processor,
          @options.merge(
            'displayUrl' => @original_url,
            viewport: @viewport
          )
        )
      end

      def processor
        HtmlProcessor.new(Dir.pwd)
      end

      def response_body_for_processor
        HtmlPreprocessor.new(@original_response_body).to_s
      end
    end

    class HtmlPreprocessor
      def initialize(html_as_string)
        @html_as_string = html_as_string
      end

      def to_s
        append_dynamic_rendering_variable!
        @html_as_string
      end

      private

      PRERENDER_VARIABLE = "<script type=\"text/javascript\">window.dynamicRendering = true;</script>"

      def append_dynamic_rendering_variable!
        @html_as_string.sub!(/<head[^>]*>/, "\\0#{PRERENDER_VARIABLE}")
      end
    end

    class HtmlPostProcessor
      def initialize(html_as_string)
        @html = Nokogiri::HTML(html_as_string)
      end

      def to_s
        remove_javascript!
        @html.to_s
      end

      private

      JAVASCRIPT_SELECTOR = 'script:not([type]), script[type="text/javascript"]'

      def remove_javascript!
        @html.css(JAVASCRIPT_SELECTOR).remove
      end
    end

    class HtmlProcessor < ::Grover::Processor
      def convert(method, url_or_html, options)
        spawn_process
        ensure_packages_are_initiated
        result = call_js_method method, url_or_html, options
        return unless result

        result
      ensure
        cleanup_process if stdin
      end
    end
  end
end
