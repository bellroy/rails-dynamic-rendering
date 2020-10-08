![dynamic-rendering-logo](https://user-images.githubusercontent.com/2643026/94681334-28e48f80-031b-11eb-8dd5-010e6e23500c.png)

# Dynamic Rendering [![Gem Version](https://badge.fury.io/rb/rails-dynamic-rendering.svg)](https://badge.fury.io/rb/rails-dynamic-rendering) ![CI Badge](https://github.com/tricycle/rails-dynamic-rendering/workflows/RSpec%20Test%20Suite/badge.svg)

Is your SEO performance being held hostage by frontend JavaScript UI frameworks? Dynamic rendering is a "workaround solution" (in the words of Google) to help make difficult to index JavaScript based content easier for search engine crawlers to understand by presenting them with a pre-rendered HTML snapshot of your page.

This gem implements dynamic rendering for Rails applications using [Puppeteer](https://github.com/puppeteer/puppeteer) via the [Grover](https://github.com/Studiosity/grover) gem.

You can find out more about dynamic rendering in Google's article:
https://developers.google.com/search/docs/guides/dynamic-rendering

## Is this server-side rendering / SSR?

Kind of - Server-side rendering typically involves pre-rendering JavaScript elements of the page on the server within some isolated NodeJS environment and then having the client "re-hydrate" the DOM after loading. Dynamic rendering differs in that it's targeted specifically at crawler user agents and doesn't involve any "re-hydration" of the DOM, rather it's a static representation of the DOM, a snapshot of how the page looked in a headless Chrome instance.

## How does this work?

![diagram](https://user-images.githubusercontent.com/2643026/94683948-39970480-031f-11eb-9ea7-e90a03b0529b.jpg)

## Install

`gem 'rails-dynamic-rendering'`

## Usage

Include the concern and then use `enable_dynamic_rendering`. Any controller action covered by the `enable_dynamic_rendering` call (which accepts all the same arguments as `after_action`) will based on the user agent choose to either just return the HTML with JS or choose to render the page in a headless Chrome instance & render back the serialized HTML with all JS removed.

```ruby
class ApplicationController
  include DynamicRendering::ActsAsDynamicallyRenderable

  enable_dynamic_rendering only: :index, if: -> { some_condition_is_met? }

  def index
    @my_code = 'Does fancy stuff'
  end

  private

  def some_condition_is_met?
    true
  end
end

```

You can override the built in decision making thats used to determine whether a snapshot of the page should be returned by defining your own `#request_suitable_for_dynamic_rendering?` method. You might want to do this if you'd like to target other user agents:

```ruby
def request_suitable_for_dynamic_rendering?
  request.user_agent.include? 'My Problematic Bot That Does Not Render JS Content'
end
```
