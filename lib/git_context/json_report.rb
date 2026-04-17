# frozen_string_literal: true

require "json"

module GitContext
  # Collector and serializer for structured git context as JSON.
  # Gathers actions, proposals, context data, and warnings, then emits
  # them in a contract-shaped hash and JSON.
  class JsonReport
    def initialize(command:, version: GitContext::VERSION)
      @command = command
      @version = version
      @exit_code = 0
      @actions_taken = []
      @proposals = []
      @context = {}
      @warnings = []
    end

    def add_action(kind:, description:, details: {})
      @actions_taken << {
        "kind" => kind,
        "description" => description,
        "details" => details
      }
    end

    def add_proposal(kind:, description:, details: {}, suggested_command: nil)
      @proposals << {
        "kind" => kind,
        "description" => description,
        "details" => details,
        "suggested_command" => suggested_command
      }
    end

    def add_warning(kind:, description:)
      @warnings << {
        "kind" => kind,
        "description" => description
      }
    end

    def set_context(hash)
      @context = hash
    end

    def merge_context(hash)
      @context.merge!(hash)
    end

    def fail!(code)
      @exit_code = code
    end

    def to_h
      {
        "command" => @command,
        "version" => @version,
        "exit_code" => @exit_code,
        "actions_taken" => @actions_taken,
        "proposals" => @proposals,
        "context" => @context,
        "warnings" => @warnings
      }
    end

    def to_json(pretty: false)
      if pretty
        JSON.pretty_generate(to_h)
      else
        JSON.generate(to_h)
      end
    end
  end
end
