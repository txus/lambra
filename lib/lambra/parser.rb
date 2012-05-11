require 'lambra/parser/parser'

class Lambra::Parser
  # include Lambra::Syntax

  def self.parse_to_sexp(string)
    parser = new string
    unless parser.parse
      parser.raise_error
    end

    parser.result.to_sexp
  end

  attr_reader :line, :column

  def position(line, column)
    @line = line
    @column = column
  end
end
