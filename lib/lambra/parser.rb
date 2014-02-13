require 'lambra/parser/parser'

class Lambra::Parser
  def self.parse(*args)
    parse_string(*args)
  end

  def self.parse_string(string, debug=false)
    new.parse_string(string, debug)
  end

  def self.parse_to_sexp(string, debug=false)
    parse_string(string, debug).to_sexp
  end

  def self.parse_file(name, debug=false)
    new.parse_file(name, debug)
  end

  def initialize
  end

  def parse_string(string, debug=false)
    setup_parser string, debug
    raise_error unless parse
    result
  end

  def parse_file(name, debug=false)
    setup_parser IO.read(name), debug
    raise_error unless parse
    result
  end

  def pre_exe
    []
  end
end
