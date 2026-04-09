require_relative "lib/promotable/version"

Gem::Specification.new do |spec|
  spec.name        = "promotable"
  spec.version     = Promotable::VERSION
  spec.authors     = [ "Mohamed Magdy" ]
  spec.email       = [ "mohamedmagdysaber@gmail.com" ]
  spec.homepage    = "https://github.com/mohamedmagdy/promotable"
  spec.summary     = "Extensible promotion and coupon engine for Rails"
  spec.description = "A Rails engine providing a type-agnostic, extensible promotion system with STI-based rules and actions, a registry for custom types, and concerns for seamless host-app integration."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "concurrent-ruby", ">= 1.2"
end
