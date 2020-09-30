# typed: false
# frozen_string_literal: true

require 'rails_helper'

module DynamicRendering
  describe ActsAsDynamicallyRenderable, type: :controller do
    described_class.tap do |concern|
      controller(ActionController::Base) do
        include concern

        enable_dynamic_rendering

        def index
          case params[:scenario]
          when 'ok-json'
            render json: { hello: 'world' }
          when 'not-ok-html'
            html = <<~HTML
              <html>
                <head><title>404!</title></head>
                <body>404!</body>
              </html>
            HTML
            render status: :not_found, html: html.html_safe
          when 'ok-html'
            html = <<~HTML
              <html>
                <head>
                  <title>Hello World</title>
                </head>
                <body>
                  <script type="text/javascript">
                    console.log('Hello world!');
                  </script>
                  <p>Hello world!</p>
                  <script type="application/ld+json">
                    { "hello": "world" }
                  </script>
                  <script>
                    var myDynamicNode = document.createElement("P");
                    myDynamicNode.appendChild(document.createTextNode("Hello Dynamic World"));
                    document.body.appendChild(myDynamicNode);
                  </script>
                </body>
              </html>
            HTML
            render html: html.html_safe
          else
            raise ArgumentError, "Unknown test scenario"
          end
        end
      end
    end

    describe '#render_dynamically' do
      subject(:make_request) do
        request.headers.merge!(headers)
        get :index, params: params
      end

      let(:params) do
        { scenario: scenario }
      end
      let(:headers) do
        { 'HTTP_USER_AGENT' => user_agent }
      end
      let(:scenario) { 'ok-html' }
      let(:user_agent) { 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1' }

      shared_examples_for 'it does not use dynamic rendering' do |expected_body, expected_status|
        specify do
          expect(DynamicRendering::ActsAsDynamicallyRenderable::HtmlProcessor)
            .not_to receive(:new)
          make_request
          expect(response.body).to match(expected_body)
          expect(response).to have_http_status(expected_status)
        end
      end

      context 'when the request is not coming from a supported crawler' do
        let(:user_agent) { 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1' }

        it_behaves_like 'it does not use dynamic rendering', /console.log/, :ok
      end

      context 'when the request is coming from a supported crawler' do
        let(:user_agent) { 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' }

        context 'when the response status is not ok' do
          let(:scenario) { 'not-ok-html' }

          it_behaves_like 'it does not use dynamic rendering', /404/, :not_found
        end

        context 'when the response status is ok' do
          context 'when the response type is not HTML' do
            let(:scenario) { 'ok-json' }

            it_behaves_like 'it does not use dynamic rendering', '{"hello":"world"}', :ok
          end

          context 'when the response type is HTML' do
            let(:html_processor) do
              instance_double(DynamicRendering::ActsAsDynamicallyRenderable::HtmlProcessor)
            end
            let(:expected_preprocessed_html) do
              <<~HTML
              <html>
                <head><script type="text/javascript">window.dynamicRendering = true;</script>
                  <title>Hello World</title>
                </head>
                <body>
                  <script type="text/javascript">
                    console.log('Hello world!');
                  </script>
                  <p>Hello world!</p>
                  <script type="application/ld+json">
                    { "hello": "world" }
                  </script>
                  <script>
                    var myDynamicNode = document.createElement("P");
                    myDynamicNode.appendChild(document.createTextNode("Hello Dynamic World"));
                    document.body.appendChild(myDynamicNode);
                  </script>
                </body>
              </html>
              HTML
            end
            let(:rendered_html) do
              <<~HTML
                <html>
                  <head><script type="text/javascript">window.dynamicRendering = true;</script>
                    <title>Hello World</title>
                  </head>
                  <body>
                    <script type="text/javascript">
                      console.log('Hello world!');
                    </script>
                    <p>Hello world!</p>
                    <script type="application/ld+json">
                      { "hello": "world" }
                    </script>
                    <script>
                      var myDynamicNode = document.createElement("P");
                      myDynamicNode.appendChild(document.createTextNode("Hello Dynamic World"));
                      document.body.appendChild(myDynamicNode);
                    </script>
                    <p>Hello Dynamic World</p>
                  </body>
                </html>
              HTML
            end

            before do
              expect(DynamicRendering::ActsAsDynamicallyRenderable::HtmlProcessor)
                .to receive(:new)
                .and_return(html_processor)
              expect(html_processor)
                .to receive(:convert)
                .with(
                  'content',
                  expected_preprocessed_html,
                  {
                    'displayUrl' => 'http://test.host/anonymous?scenario=ok-html',
                    'waitUntil' => 'networkidle2',
                    viewport: { width: 1400, height: 950 }
                  }
                )
                .and_return(rendered_html)
              make_request
            end

            it 'removes javascript' do
              expect(response.body).not_to include('document.createTextNode')
            end

            it 'leaves JSON-LD in place' do
              expect(response.body).to include('{ "hello": "world" }')
            end
          end
        end
      end
    end
  end
end
