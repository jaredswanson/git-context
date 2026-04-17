# frozen_string_literal: true

module GitContext
  # Caps each per-file section of a unified diff to max_lines_per_file body
  # lines. Body lines are the +/- / context lines that follow the header
  # (diff --git / index / --- / +++ / @@) — we don't count the header itself.
  class TruncatedDiff
    FILE_BOUNDARY = /^diff --git /

    def initialize(raw, max_lines_per_file:)
      @raw = raw
      @limit = max_lines_per_file
    end

    def to_s
      return "" if @raw.empty?

      split_files.map { |file| truncate_file(file) }.join
    end

    private

    def split_files
      chunks = []
      current = +""
      @raw.each_line do |line|
        if line.match?(FILE_BOUNDARY) && !current.empty?
          chunks << current
          current = +""
        end
        current << line
      end
      chunks << current unless current.empty?
      chunks
    end

    def truncate_file(file)
      lines = file.lines
      header_end = lines.index { |l| l.start_with?("@@") } || lines.length - 1
      header = lines[0..header_end]
      body = lines[(header_end + 1)..] || []

      return file if body.length <= @limit

      kept = body.first(@limit)
      dropped = body.length - @limit
      (header + kept).join + "... #{dropped} more lines truncated\n"
    end
  end
end
