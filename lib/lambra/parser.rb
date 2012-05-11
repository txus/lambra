require 'lambra/parser/parser'

class Lambra::Parser
  def self.parse_to_sexp(string)
    parser = new string
    unless parser.parse
      parser.raise_error
    end

    parser.result.to_sexp
  end
end
