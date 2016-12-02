module Abid
  class CLI
    class TableFormatter
      def initialize(body, header = nil)
        @body = body
        @header = header
      end

      def format
        result = ''

        if @header
          result << format_row(@header)
          result << format_row(@header.length, '-')
        end

        @body.each do |row|
          result << format_row(row)
        end

        result
      end

      def tab_width
        return @tab_width if @tab_width

        cols_num = (@header || @body.first).length

        @tab_width = Array.new(cols_num) do |i|
          w = @body.map { |row| row[i].to_s.length }.max || 0
          @header ? [w, @header[i].length].max : w
        end
      end

      def format_row(row)
        row.map.with_index do |v, i|
          v.to_s.ljust(tab_width[i] + 2)
        end.join('').rstrip + "\n"
      end
    end
  end
end
