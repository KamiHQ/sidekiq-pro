Gem::Specification.new do |s|
  s.name = "sidekiq-pro".freeze
  s.version = "4.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://gems.contribsys.com", "changelog_uri" => "https://github.com/mperham/sidekiq/blob/master/Pro-Changes.md", "documentation_uri" => "https://github.com/mperham/sidekiq/wiki", "wiki_uri" => "https://github.com/mperham/sidekiq/wiki" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Mike Perham".freeze]
  s.date = "2019-02-08"
  s.description = "Loads of additional functionality for Sidekiq".freeze
  s.email = ["mike@contribsys.com".freeze]
  s.homepage = "http://sidekiq.org".freeze
  s.licenses = ["Nonstandard".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Black belt functionality for Sidekiq".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sidekiq>.freeze, [">= 5.2.1"])
      s.add_runtime_dependency(%q<concurrent-ruby>.freeze, [">= 1.0.5"])
      s.add_development_dependency(%q<statsd-ruby>.freeze, [">= 0"])
      s.add_development_dependency(%q<dogstatsd-ruby>.freeze, [">= 0"])
    else
      s.add_dependency(%q<sidekiq>.freeze, [">= 5.2.1"])
      s.add_dependency(%q<concurrent-ruby>.freeze, [">= 1.0.5"])
      s.add_dependency(%q<statsd-ruby>.freeze, [">= 0"])
      s.add_dependency(%q<dogstatsd-ruby>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<sidekiq>.freeze, [">= 5.2.1"])
    s.add_dependency(%q<concurrent-ruby>.freeze, [">= 1.0.5"])
    s.add_dependency(%q<statsd-ruby>.freeze, [">= 0"])
    s.add_dependency(%q<dogstatsd-ruby>.freeze, [">= 0"])
  end
end