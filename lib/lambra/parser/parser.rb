class Lambra::Parser
  # :stopdoc:

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end



    # Prepares for parsing +str+.  If you define a custom initialize you must
    # call this method before #parse
    def setup_parser(str, debug=false)
      set_string str, 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @failed_rule = nil
      @failing_rule_offset = -1

      setup_foreign_grammar
    end

    attr_reader :string
    attr_reader :failing_rule_offset
    attr_accessor :result, :pos

    def current_column(target=pos)
      if c = string.rindex("\n", target-1)
        return target - c - 1
      end

      target + 1
    end

    def current_line(target=pos)
      cur_offset = 0
      cur_line = 0

      string.each_line do |line|
        cur_line += 1
        cur_offset += line.size
        return cur_line if cur_offset >= target
      end

      -1
    end

    def lines
      lines = []
      string.each_line { |l| lines << l }
      lines
    end



    def get_text(start)
      @string[start..@pos-1]
    end

    # Sets the string and current parsing position for the parser.
    def set_string string, pos
      @string = string
      @string_size = string ? string.size : 0
      @pos = pos
    end

    def show_pos
      width = 10
      if @pos < width
        "#{@pos} (\"#{@string[0,@pos]}\" @ \"#{@string[@pos,width]}\")"
      else
        "#{@pos} (\"... #{@string[@pos - width, width]}\" @ \"#{@string[@pos,width]}\")"
      end
    end

    def failure_info
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "line #{l}, column #{c}: failed rule '#{info.name}' = '#{info.rendered}'"
      else
        "line #{l}, column #{c}: failed rule '#{@failed_rule}'"
      end
    end

    def failure_caret
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      line = lines[l-1]
      "#{line}\n#{' ' * (c - 1)}^"
    end

    def failure_character
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset
      lines[l-1][c-1, 1]
    end

    def failure_oneline
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      char = lines[l-1][c-1, 1]

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "@#{l}:#{c} failed rule '#{info.name}', got '#{char}'"
      else
        "@#{l}:#{c} failed rule '#{@failed_rule}', got '#{char}'"
      end
    end

    class ParseError < RuntimeError
    end

    def raise_error
      raise ParseError, failure_oneline
    end

    def show_error(io=STDOUT)
      error_pos = @failing_rule_offset
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "On line #{line_no}, column #{col_no}:"

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        io.puts "Failed to match '#{info.rendered}' (rule '#{info.name}')"
      else
        io.puts "Failed to match rule '#{@failed_rule}'"
      end

      io.puts "Got: #{string[error_pos,1].inspect}"
      line = lines[line_no-1]
      io.puts "=> #{line}"
      io.print(" " * (col_no + 3))
      io.puts "^"
    end

    def set_failed_rule(name)
      if @pos > @failing_rule_offset
        @failed_rule = name
        @failing_rule_offset = @pos
      end
    end

    attr_reader :failed_rule

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def scan(reg)
      if m = reg.match(@string[@pos..-1])
        width = m.end(0)
        @pos += width
        return true
      end

      return nil
    end

    if "".respond_to? :ord
      def get_byte
        if @pos >= @string_size
          return nil
        end

        s = @string[@pos].ord
        @pos += 1
        s
      end
    else
      def get_byte
        if @pos >= @string_size
          return nil
        end

        s = @string[@pos]
        @pos += 1
        s
      end
    end

    def parse(rule=nil)
      # We invoke the rules indirectly via apply
      # instead of by just calling them as methods because
      # if the rules use left recursion, apply needs to
      # manage that.

      if !rule
        apply(:_root)
      else
        method = rule.gsub("-","_hyphen_")
        apply :"_#{method}"
      end
    end

    class MemoEntry
      def initialize(ans, pos)
        @ans = ans
        @pos = pos
        @result = nil
        @set = false
        @left_rec = false
      end

      attr_reader :ans, :pos, :result, :set
      attr_accessor :left_rec

      def move!(ans, pos, result)
        @ans = ans
        @pos = pos
        @result = result
        @set = true
        @left_rec = false
      end
    end

    def external_invoke(other, rule, *args)
      old_pos = @pos
      old_string = @string

      set_string other.string, other.pos

      begin
        if val = __send__(rule, *args)
          other.pos = @pos
          other.result = @result
        else
          other.set_failed_rule "#{self.class}##{rule}"
        end
        val
      ensure
        set_string old_string, old_pos
      end
    end

    def apply_with_args(rule, *args)
      memo_key = [rule, args]
      if m = @memoizations[memo_key][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[memo_key][@pos] = m
        start_pos = @pos

        ans = __send__ rule, *args

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, args, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def apply(rule)
      if m = @memoizations[rule][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ rule

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, nil, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def grow_lr(rule, args, start_pos, m)
      while true
        @pos = start_pos
        @result = m.result

        if args
          ans = __send__ rule, *args
        else
          ans = __send__ rule
        end
        return nil unless ans

        break if @pos <= m.pos

        m.move! ans, @pos, @result
      end

      @result = m.result
      @pos = m.pos
      return m.ans
    end

    class RuleInfo
      def initialize(name, rendered)
        @name = name
        @rendered = rendered
      end

      attr_reader :name, :rendered
    end

    def self.rule_info(name, rendered)
      RuleInfo.new(name, rendered)
    end


  # :startdoc:

 attr_accessor :ast 

  # :stopdoc:

  module ::Lambra::AST
    class Node; end
    class Character < Node
      def initialize(line, column, value)
        @line = line
        @column = column
        @value = value
      end
      attr_reader :line
      attr_reader :column
      attr_reader :value
    end
    class False < Node
      def initialize(line, column)
        @line = line
        @column = column
      end
      attr_reader :line
      attr_reader :column
    end
    class Keyword < Node
      def initialize(line, column, name)
        @line = line
        @column = column
        @name = name
      end
      attr_reader :line
      attr_reader :column
      attr_reader :name
    end
    class List < Node
      def initialize(line, column, elements)
        @line = line
        @column = column
        @elements = elements
      end
      attr_reader :line
      attr_reader :column
      attr_reader :elements
    end
    class Map < Node
      def initialize(line, column, elements)
        @line = line
        @column = column
        @elements = elements
      end
      attr_reader :line
      attr_reader :column
      attr_reader :elements
    end
    class Nil < Node
      def initialize(line, column)
        @line = line
        @column = column
      end
      attr_reader :line
      attr_reader :column
    end
    class Number < Node
      def initialize(line, column, value)
        @line = line
        @column = column
        @value = value
      end
      attr_reader :line
      attr_reader :column
      attr_reader :value
    end
    class Sequence < Node
      def initialize(line, column, elements)
        @line = line
        @column = column
        @elements = elements
      end
      attr_reader :line
      attr_reader :column
      attr_reader :elements
    end
    class Set < Node
      def initialize(line, column, elements)
        @line = line
        @column = column
        @elements = elements
      end
      attr_reader :line
      attr_reader :column
      attr_reader :elements
    end
    class String < Node
      def initialize(line, column, value)
        @line = line
        @column = column
        @value = value
      end
      attr_reader :line
      attr_reader :column
      attr_reader :value
    end
    class Symbol < Node
      def initialize(line, column, name)
        @line = line
        @column = column
        @name = name
      end
      attr_reader :line
      attr_reader :column
      attr_reader :name
    end
    class True < Node
      def initialize(line, column)
        @line = line
        @column = column
      end
      attr_reader :line
      attr_reader :column
    end
    class Vector < Node
      def initialize(line, column, elements)
        @line = line
        @column = column
        @elements = elements
      end
      attr_reader :line
      attr_reader :column
      attr_reader :elements
    end
  end
  module ::Lambra::ASTConstruction
    def char_value(line, column, value)
      ::Lambra::AST::Character.new(line, column, value)
    end
    def false_value(line, column)
      ::Lambra::AST::False.new(line, column)
    end
    def keyword(line, column, name)
      ::Lambra::AST::Keyword.new(line, column, name)
    end
    def list(line, column, elements)
      ::Lambra::AST::List.new(line, column, elements)
    end
    def map(line, column, elements)
      ::Lambra::AST::Map.new(line, column, elements)
    end
    def nil_value(line, column)
      ::Lambra::AST::Nil.new(line, column)
    end
    def number(line, column, value)
      ::Lambra::AST::Number.new(line, column, value)
    end
    def seq(line, column, elements)
      ::Lambra::AST::Sequence.new(line, column, elements)
    end
    def set(line, column, elements)
      ::Lambra::AST::Set.new(line, column, elements)
    end
    def string_value(line, column, value)
      ::Lambra::AST::String.new(line, column, value)
    end
    def symbol(line, column, name)
      ::Lambra::AST::Symbol.new(line, column, name)
    end
    def true_value(line, column)
      ::Lambra::AST::True.new(line, column)
    end
    def vector(line, column, elements)
      ::Lambra::AST::Vector.new(line, column, elements)
    end
  end
  include ::Lambra::ASTConstruction
  def setup_foreign_grammar; end

  # eof = !.
  def _eof
    _save = self.pos
    _tmp = get_byte
    _tmp = _tmp ? nil : true
    self.pos = _save
    set_failed_rule :_eof unless _tmp
    return _tmp
  end

  # space = (" " | "\t")
  def _space

    _save = self.pos
    while true # choice
      _tmp = match_string(" ")
      break if _tmp
      self.pos = _save
      _tmp = match_string("\t")
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_space unless _tmp
    return _tmp
  end

  # nl = "\n"
  def _nl
    _tmp = match_string("\n")
    set_failed_rule :_nl unless _tmp
    return _tmp
  end

  # sp = space+
  def _sp
    _save = self.pos
    _tmp = apply(:_space)
    if _tmp
      while true
        _tmp = apply(:_space)
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    set_failed_rule :_sp unless _tmp
    return _tmp
  end

  # - = space*
  def __hyphen_
    while true
      _tmp = apply(:_space)
      break unless _tmp
    end
    _tmp = true
    set_failed_rule :__hyphen_ unless _tmp
    return _tmp
  end

  # comment = ";" (!nl .)* nl
  def _comment

    _save = self.pos
    while true # sequence
      _tmp = match_string(";")
      unless _tmp
        self.pos = _save
        break
      end
      while true

        _save2 = self.pos
        while true # sequence
          _save3 = self.pos
          _tmp = apply(:_nl)
          _tmp = _tmp ? nil : true
          self.pos = _save3
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = get_byte
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_nl)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_comment unless _tmp
    return _tmp
  end

  # br-sp = (space | "," | nl)*
  def _br_hyphen_sp
    while true

      _save1 = self.pos
      while true # choice
        _tmp = apply(:_space)
        break if _tmp
        self.pos = _save1
        _tmp = match_string(",")
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_nl)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      break unless _tmp
    end
    _tmp = true
    set_failed_rule :_br_hyphen_sp unless _tmp
    return _tmp
  end

  # number = < /[1-9][0-9]*/ > { text }
  def _number

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[1-9][0-9]*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_number unless _tmp
    return _tmp
  end

  # integer = number:n {number(current_line, current_column, n.to_i)}
  def _integer

    _save = self.pos
    while true # sequence
      _tmp = apply(:_number)
      n = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; number(current_line, current_column, n.to_i); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_integer unless _tmp
    return _tmp
  end

  # float = number:w "." number:f {number(current_line, current_column, "#{w}.#{f}".to_f)}
  def _float

    _save = self.pos
    while true # sequence
      _tmp = apply(:_number)
      w = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(".")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_number)
      f = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; number(current_line, current_column, "#{w}.#{f}".to_f); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_float unless _tmp
    return _tmp
  end

  # hexdigits = /[0-9A-Fa-f]/
  def _hexdigits
    _tmp = scan(/\A(?-mix:[0-9A-Fa-f])/)
    set_failed_rule :_hexdigits unless _tmp
    return _tmp
  end

  # hex = "0x" < hexdigits+ > {number(current_line, current_column, text.to_i(16))}
  def _hex

    _save = self.pos
    while true # sequence
      _tmp = match_string("0x")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _save1 = self.pos
      _tmp = apply(:_hexdigits)
      if _tmp
        while true
          _tmp = apply(:_hexdigits)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; number(current_line, current_column, text.to_i(16)); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_hex unless _tmp
    return _tmp
  end

  # true = "true" {true_value(current_line, current_column)}
  def _true

    _save = self.pos
    while true # sequence
      _tmp = match_string("true")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; true_value(current_line, current_column); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_true unless _tmp
    return _tmp
  end

  # false = "false" {false_value(current_line, current_column)}
  def _false

    _save = self.pos
    while true # sequence
      _tmp = match_string("false")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; false_value(current_line, current_column); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_false unless _tmp
    return _tmp
  end

  # nil = "nil" {nil_value(current_line, current_column)}
  def _nil

    _save = self.pos
    while true # sequence
      _tmp = match_string("nil")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; nil_value(current_line, current_column); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_nil unless _tmp
    return _tmp
  end

  # word = < /\.?[a-zA-Z0-9_\-\*\+\-\/]+/ > { text }
  def _word

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:\.?[a-zA-Z0-9_\-\*\+\-\/]+)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_word unless _tmp
    return _tmp
  end

  # symbol = word:w {symbol(current_line, current_column, w.to_sym)}
  def _symbol

    _save = self.pos
    while true # sequence
      _tmp = apply(:_word)
      w = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; symbol(current_line, current_column, w.to_sym); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_symbol unless _tmp
    return _tmp
  end

  # keyword = ":" word:w {keyword(current_line, current_column, w.to_sym)}
  def _keyword

    _save = self.pos
    while true # sequence
      _tmp = match_string(":")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_word)
      w = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; keyword(current_line, current_column, w.to_sym); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_keyword unless _tmp
    return _tmp
  end

  # string = "\"" < /[^\\"]*/ > "\"" {string_value(current_line, current_column, text)}
  def _string

    _save = self.pos
    while true # sequence
      _tmp = match_string("\"")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[^\\"]*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("\"")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; string_value(current_line, current_column, text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_string unless _tmp
    return _tmp
  end

  # character = "\\" word:w {char_value(current_line, current_column, w.to_sym)}
  def _character

    _save = self.pos
    while true # sequence
      _tmp = match_string("\\")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_word)
      w = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; char_value(current_line, current_column, w.to_sym); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_character unless _tmp
    return _tmp
  end

  # quote = "'" word:w {list(current_line, current_column, [symbol(current_line, current_column, :quote), symbol(current_line, current_column, w.to_sym)])}
  def _quote

    _save = self.pos
    while true # sequence
      _tmp = match_string("'")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_word)
      w = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; list(current_line, current_column, [symbol(current_line, current_column, :quote), symbol(current_line, current_column, w.to_sym)]); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_quote unless _tmp
    return _tmp
  end

  # deref = "@" word:w {list(current_line, current_column, [symbol(current_line, current_column, :deref), symbol(current_line, current_column, w.to_sym)])}
  def _deref

    _save = self.pos
    while true # sequence
      _tmp = match_string("@")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_word)
      w = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; list(current_line, current_column, [symbol(current_line, current_column, :deref), symbol(current_line, current_column, w.to_sym)]); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_deref unless _tmp
    return _tmp
  end

  # macro = (quote | deref)
  def _macro

    _save = self.pos
    while true # choice
      _tmp = apply(:_quote)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_deref)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_macro unless _tmp
    return _tmp
  end

  # literal = (float | integer | hex | true | false | nil | string | character | vector | set | map | symbol | macro | keyword)
  def _literal

    _save = self.pos
    while true # choice
      _tmp = apply(:_float)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_integer)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_hex)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_true)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_false)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_nil)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_string)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_character)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_vector)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_set)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_map)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_symbol)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_macro)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_keyword)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_literal unless _tmp
    return _tmp
  end

  # list = ("(" expr_list:e ")" {list(current_line, current_column, e)} | "(" ")" {list(current_line, current_column, [])})
  def _list

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("(")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_expr_list)
        e = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(")")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; list(current_line, current_column, e); end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("(")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string(")")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; list(current_line, current_column, []); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_list unless _tmp
    return _tmp
  end

  # vector = ("[" expr_list:e "]" {vector(current_line, current_column, e)} | "[" "]" {vector(current_line, current_column, [])})
  def _vector

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("[")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_expr_list)
        e = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("]")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; vector(current_line, current_column, e); end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("[")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("]")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; vector(current_line, current_column, []); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_vector unless _tmp
    return _tmp
  end

  # set = ("#{" expr_list:e "}" {set(current_line, current_column, e)} | "#{" "}" {set(current_line, current_column, [])})
  def _set

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\#{")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_expr_list)
        e = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("}")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; set(current_line, current_column, e); end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("\#{")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("}")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; set(current_line, current_column, []); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_set unless _tmp
    return _tmp
  end

  # map = ("{" expr_list:e "}" {map(current_line, current_column, Hash[*e])} | "{" "}" {map(current_line, current_column, {})})
  def _map

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("{")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_expr_list)
        e = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("}")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; map(current_line, current_column, Hash[*e]); end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("{")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("}")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; map(current_line, current_column, {}); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_map unless _tmp
    return _tmp
  end

  # expr = (list | literal)
  def _expr

    _save = self.pos
    while true # choice
      _tmp = apply(:_list)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_literal)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_expr unless _tmp
    return _tmp
  end

  # many_expr = (comment:e many_expr:m { [e] + m } | expr:e br-sp many_expr:m { [e] + m } | br-sp many_expr:m br-sp { m } | expr:e { [e] })
  def _many_expr

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_comment)
        e = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_many_expr)
        m = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  [e] + m ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_expr)
        e = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_br_hyphen_sp)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_many_expr)
        m = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [e] + m ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = apply(:_br_hyphen_sp)
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_many_expr)
        m = @result
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_br_hyphen_sp)
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  m ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = apply(:_expr)
        e = @result
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  [e] ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_many_expr unless _tmp
    return _tmp
  end

  # sequence = many_expr:e { e.size > 1 ? seq(current_line, current_column, e) : e.first }
  def _sequence

    _save = self.pos
    while true # sequence
      _tmp = apply(:_many_expr)
      e = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  e.size > 1 ? seq(current_line, current_column, e) : e.first ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_sequence unless _tmp
    return _tmp
  end

  # expr_list_b = (expr:e br-sp expr_list_b:l { [e] + l } | expr:e { [e] })
  def _expr_list_b

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_expr)
        e = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_br_hyphen_sp)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_expr_list_b)
        l = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  [e] + l ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_expr)
        e = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [e] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_expr_list_b unless _tmp
    return _tmp
  end

  # expr_list = br-sp expr_list_b:b br-sp { b }
  def _expr_list

    _save = self.pos
    while true # sequence
      _tmp = apply(:_br_hyphen_sp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_expr_list_b)
      b = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_br_hyphen_sp)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  b ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_expr_list unless _tmp
    return _tmp
  end

  # root = sequence:e eof { @ast = e }
  def _root

    _save = self.pos
    while true # sequence
      _tmp = apply(:_sequence)
      e = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_eof)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @ast = e ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_eof] = rule_info("eof", "!.")
  Rules[:_space] = rule_info("space", "(\" \" | \"\\t\")")
  Rules[:_nl] = rule_info("nl", "\"\\n\"")
  Rules[:_sp] = rule_info("sp", "space+")
  Rules[:__hyphen_] = rule_info("-", "space*")
  Rules[:_comment] = rule_info("comment", "\";\" (!nl .)* nl")
  Rules[:_br_hyphen_sp] = rule_info("br-sp", "(space | \",\" | nl)*")
  Rules[:_number] = rule_info("number", "< /[1-9][0-9]*/ > { text }")
  Rules[:_integer] = rule_info("integer", "number:n {number(current_line, current_column, n.to_i)}")
  Rules[:_float] = rule_info("float", "number:w \".\" number:f {number(current_line, current_column, \"\#{w}.\#{f}\".to_f)}")
  Rules[:_hexdigits] = rule_info("hexdigits", "/[0-9A-Fa-f]/")
  Rules[:_hex] = rule_info("hex", "\"0x\" < hexdigits+ > {number(current_line, current_column, text.to_i(16))}")
  Rules[:_true] = rule_info("true", "\"true\" {true_value(current_line, current_column)}")
  Rules[:_false] = rule_info("false", "\"false\" {false_value(current_line, current_column)}")
  Rules[:_nil] = rule_info("nil", "\"nil\" {nil_value(current_line, current_column)}")
  Rules[:_word] = rule_info("word", "< /\\.?[a-zA-Z0-9_\\-\\*\\+\\-\\/]+/ > { text }")
  Rules[:_symbol] = rule_info("symbol", "word:w {symbol(current_line, current_column, w.to_sym)}")
  Rules[:_keyword] = rule_info("keyword", "\":\" word:w {keyword(current_line, current_column, w.to_sym)}")
  Rules[:_string] = rule_info("string", "\"\\\"\" < /[^\\\\\"]*/ > \"\\\"\" {string_value(current_line, current_column, text)}")
  Rules[:_character] = rule_info("character", "\"\\\\\" word:w {char_value(current_line, current_column, w.to_sym)}")
  Rules[:_quote] = rule_info("quote", "\"'\" word:w {list(current_line, current_column, [symbol(current_line, current_column, :quote), symbol(current_line, current_column, w.to_sym)])}")
  Rules[:_deref] = rule_info("deref", "\"@\" word:w {list(current_line, current_column, [symbol(current_line, current_column, :deref), symbol(current_line, current_column, w.to_sym)])}")
  Rules[:_macro] = rule_info("macro", "(quote | deref)")
  Rules[:_literal] = rule_info("literal", "(float | integer | hex | true | false | nil | string | character | vector | set | map | symbol | macro | keyword)")
  Rules[:_list] = rule_info("list", "(\"(\" expr_list:e \")\" {list(current_line, current_column, e)} | \"(\" \")\" {list(current_line, current_column, [])})")
  Rules[:_vector] = rule_info("vector", "(\"[\" expr_list:e \"]\" {vector(current_line, current_column, e)} | \"[\" \"]\" {vector(current_line, current_column, [])})")
  Rules[:_set] = rule_info("set", "(\"\#{\" expr_list:e \"}\" {set(current_line, current_column, e)} | \"\#{\" \"}\" {set(current_line, current_column, [])})")
  Rules[:_map] = rule_info("map", "(\"{\" expr_list:e \"}\" {map(current_line, current_column, Hash[*e])} | \"{\" \"}\" {map(current_line, current_column, {})})")
  Rules[:_expr] = rule_info("expr", "(list | literal)")
  Rules[:_many_expr] = rule_info("many_expr", "(comment:e many_expr:m { [e] + m } | expr:e br-sp many_expr:m { [e] + m } | br-sp many_expr:m br-sp { m } | expr:e { [e] })")
  Rules[:_sequence] = rule_info("sequence", "many_expr:e { e.size > 1 ? seq(current_line, current_column, e) : e.first }")
  Rules[:_expr_list_b] = rule_info("expr_list_b", "(expr:e br-sp expr_list_b:l { [e] + l } | expr:e { [e] })")
  Rules[:_expr_list] = rule_info("expr_list", "br-sp expr_list_b:b br-sp { b }")
  Rules[:_root] = rule_info("root", "sequence:e eof { @ast = e }")
  # :startdoc:
end
