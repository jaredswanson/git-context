# frozen_string_literal: true

module GitContext
  module RepoAudit
    module Sections
    end
  end
end

require "git_context/repo_audit/sections/gitignore_gaps"
require "git_context/repo_audit/sections/tracked_secrets"
require "git_context/repo_audit/sections/missing_standard_files"
