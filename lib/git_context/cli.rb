# frozen_string_literal: true

module GitContext
  class CLI
    def initialize(argv:, stdout: $stdout)
      @argv = argv
      @stdout = stdout
    end

    def run
      repo = @argv.first || Dir.pwd
      @stdout.puts Report.new(git: Git.new(repo)).to_s
    end
  end
end
