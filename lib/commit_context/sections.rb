# frozen_string_literal: true

module CommitContext
  module Sections
  end
end

require "commit_context/sections/status"
require "commit_context/sections/staged_diff"
require "commit_context/sections/unstaged_diff"
require "commit_context/sections/recent_log"
require "commit_context/sections/file_history"
require "commit_context/sections/untracked_files"
