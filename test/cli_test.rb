# frozen_string_literal: true

require "test_helper"
require "stringio"

class CLITest < Minitest::Test
  include TempRepo

  def test_prints_report_for_given_repo_path
    in_temp_repo do |dir|
      write_file("a.txt", "hi")
      git("add a.txt")
      git("commit -q -m initial")
      write_file("a.txt", "bye")

      out = StringIO.new
      GitContext::CLI.new(argv: [dir], stdout: out).run

      assert_includes out.string, "Status"
      assert_includes out.string, "Unstaged changes"
      assert_includes out.string, "-hi"
      assert_includes out.string, "+bye"
      assert_includes out.string, "initial"
    end
  end

  def test_defaults_to_cwd_when_no_arg
    in_temp_repo do
      write_file("x.rb", "1")
      out = StringIO.new
      GitContext::CLI.new(argv: [], stdout: out).run

      assert_includes out.string, "x.rb"
    end
  end
end
