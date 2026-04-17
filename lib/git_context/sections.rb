# frozen_string_literal: true

module GitContext
  module Sections
  end
end

require "git_context/sections/status"
require "git_context/sections/staged_diff"
require "git_context/sections/unstaged_diff"
require "git_context/sections/recent_log"
require "git_context/sections/file_history"
require "git_context/sections/untracked_files"
