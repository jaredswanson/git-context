# frozen_string_literal: true

module GitContext
  module RepoInit
    module GitignorePatterns
      RUBY_GEM = [
        "*.gem",
        "/pkg/",
        "/doc/",
        "/tmp/",
        "/.bundle/",
        "Gemfile.lock",
        "/coverage/",
        "/.yardoc/"
      ].freeze
    end
  end
end
