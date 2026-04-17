# frozen_string_literal: true

module GitContext
  # Abstract base: default-token composition with a factory map.
  # Subclasses implement #name, #default_tokens, and #factories (private).
  class Preset
    def available_tokens
      factories.keys
    end

    def section_for(token)
      factory = factories.fetch(token) do
        raise ArgumentError, "unknown section '#{token}' for preset '#{name}'. Available: #{available_tokens.join(', ')}"
      end
      factory.call
    end

    def sections(tokens = default_tokens)
      tokens.map { |t| section_for(t) }
    end

    def name
      raise NotImplementedError
    end

    def default_tokens
      raise NotImplementedError
    end

    private

    def factories
      raise NotImplementedError
    end
  end
end
