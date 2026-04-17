# frozen_string_literal: true

module GitContext
  module Commit
    module Sections
    end
  end
end

require "git_context/commit/sections/status"
require "git_context/commit/sections/staged_diff"
require "git_context/commit/sections/unstaged_diff"
require "git_context/commit/sections/recent_log"
require "git_context/commit/sections/file_history"
require "git_context/commit/sections/untracked_files"
