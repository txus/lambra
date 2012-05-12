require 'lambra/parser/parser'

class Lambra::Parser
  def self.parse_to_sexp(string)
    parser = new string
    unless parser.parse
      parser.raise_error
    end

    parser.result.to_sexp
  end

  def self.parse(string)
    parser = new string
    unless parser.parse
      parser.raise_error
    end

    parser.result
  end

  def self.parse_file(name)
    parser = new IO.read(name)
    unless parser.parse
      parser.raise_error
    end
  end
end
