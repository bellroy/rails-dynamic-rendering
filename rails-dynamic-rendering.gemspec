lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'dynamic_rendering/version'

Gem::Specification.new do |spec|
  spec.name          = 'rails-dynamic-rendering'
  spec.version       = DynamicRendering::VERSION
  spec.authors       = ['Samuel Giles']
  spec.email         = ['samuel.giles@bellroy.com']

  spec.summary       = 'Puppeteer based dynamic rendering for Rails applications'
  spec.homepage      = 'https://github.com/tricycle/rails-dynamic-rendering'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^spec/}) && !f.match(%r{^spec/support/factories/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'grover'
  spec.add_dependency 'rails'
  spec.add_dependency 'nokogiri'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails'
end
