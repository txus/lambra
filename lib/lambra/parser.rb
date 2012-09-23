require 'lambra/parser/parser'

class Lambra::Parser
  def self.parse_to_sexp(string, debug=false)
    parser = new string, debug
    unless parser.parse
      parser.raise_error
    end

    parser.result.to_sexp
  end

  def self.parse(string, debug=false)
    parser = new string, debug
    unless parser.parse
      parser.raise_error
    end

    parser.result
  end

  def self.parse_file(name, debug=false)
    parser = new IO.read(name), debug
    unless parser.parse
      parser.raise_error
    end
  end
end
