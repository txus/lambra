require 'spec_helper'

describe "The Comment node" do
  relates ";hello\n()" do
    parse { [:sequence] }

    compile do |g|
      g.push_nil
      g.ret
    end
  end
end

describe "The Symbol node" do
  relates "hello-world" do
    parse { [:symbol, :"hello-world"] }
  end
end

describe "The Keyword node" do
  relates ":hello-world" do
    parse { [:keyword, :"hello-world"] }
  end
end

describe "The Number node" do
  relates "42" do
    parse { [:number, 42] }

    compile do |g|
      g.push_literal 42
      g.ret
    end
  end

  relates "1.23" do
    parse { [:number, 1.23] }

    compile do |g|
      g.push_literal 1.23
      g.ret
    end
  end

  relates "0x2a" do
    parse { [:number, 42] }

    compile do |g|
      g.push_literal 42
      g.ret
    end
  end
end

describe "The True node" do
  relates "true" do
    parse { [:true] }

    compile do |g|
      g.push_true
      g.ret
    end
  end
end

describe "The False node" do
  relates "false" do
    parse { [:false] }

    compile do |g|
      g.push_false
      g.ret
    end
  end
end

describe "The Nil node" do
  relates "nil" do
    parse { [:nil] }

    compile do |g|
      g.push_nil
      g.ret
    end
  end
end

describe "The String node" do
  relates '"hello, world"' do
    parse { [:string, "hello, world"] }

    compile do |g|
      g.push_literal "hello, world"
      g.ret
    end
  end
end

describe "The Character node" do
  relates '\d' do
    parse { [:character, :d] }

    compile do |g|
      g.push_literal :d
      g.ret
    end
  end
end
 
describe "The List node" do
  relates '()' do
    parse { [:list] }
  end

  relates '(1 ,   2 3)' do
    parse { [:list, [:number, 1], [:number, 2], [:number, 3]] }
  end

  relates '(hello world 43 "hey")' do
    parse { 
      [:list,
        [:symbol, :hello],
        [:symbol, :world],
        [:number, 43.0],
        [:string, "hey"]]
    }
  end

  relates "(hello \n\t (world 43) \"hey\")" do
    parse { 
      [:list,
        [:symbol, :hello],
        [:list,
          [:symbol, :world],
          [:number, 43.0]],
        [:string, "hey"]]
    }
  end
end

describe "The Vector node" do
  relates '[]' do
    parse { [:vector] }

    compile do |g|
      g.make_array 0
      g.ret
    end
  end

  relates '[1 ,   2 3]' do
    parse { [:vector, [:number, 1], [:number, 2], [:number, 3]] }

    compile do |g|
      g.push_literal 1
      g.push_literal 2
      g.push_literal 3
      g.make_array 3
      g.ret
    end
  end

  relates '[hello world 43 "hey"]' do
    parse { 
      [:vector,
        [:symbol, :hello],
        [:symbol, :world],
        [:number, 43.0],
        [:string, "hey"]]
    }

    # compile do |g|
    #   g.push_literal ???
    #   g.push_literal ???
    #   g.push_literal 43
    #   g.push_literal "hey"
    #   g.make_array 4
    #   g.ret
    # end
  end

  relates "[hello \n\t (world 43) \"hey\"]" do
    parse { 
      [:vector,
        [:symbol, :hello],
        [:list,
          [:symbol, :world],
          [:number, 43.0]],
        [:string, "hey"]]
    }
  end
end

describe "The Map node" do
  relates '{}' do
    parse { [:map] }

    compile do |g|
      g.push_cpath_top
      g.find_const :Hash
      g.meta_push_0
      g.send :new_from_literal, 1
      g.ret
    end
  end

  relates '{:a 1 :b 2}' do
    parse { [:map, {[:keyword, :a] => [:number, 1], [:keyword, :b] => [:number, 2]}] }

    compile do |g|
      g.push_cpath_top
      g.find_const :Hash
      g.meta_push_2
      g.send :new_from_literal, 1

      g.dup_top
      g.push_literal :a
      g.push_literal 1
      g.send :[]=, 2
      g.pop

      g.dup_top
      g.push_literal :b
      g.push_literal 2
      g.send :[]=, 2
      g.pop

      g.ret
    end
  end
end

describe "The Set node" do
  relates '#{}' do
    parse { [:set] }

    compile do |g|
      g.push_cpath_top
      g.find_const :Set
      g.make_array 0
      g.send :new, 1
      g.ret
    end
  end

  relates '#{:a :b :c}' do
    parse { [:set, [:keyword, :a], [:keyword, :b], [:keyword, :c]] }

    compile do |g|
      g.push_cpath_top
      g.find_const :Set
      g.push_literal :a
      g.push_literal :b
      g.push_literal :c
      g.make_array 3
      g.send :new, 1
      g.ret
    end
  end
end

describe "Macros" do
  relates "'foo" do
    parse do
      [:list,
        [:symbol, :quote],
        [:symbol, :foo]]
    end
  end

  relates "@foo" do
    parse do
      [:list,
        [:symbol, :deref],
        [:symbol, :foo]]
    end
  end
end
