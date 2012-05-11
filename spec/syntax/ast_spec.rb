require 'spec_helper'

describe "The Comment node" do
  relates ";hello\n()" do
    parse { [:sequence] }
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
  end

  relates "1.23" do
    parse { [:number, 1.23] }
  end

  relates "0x2a" do
    parse { [:number, 42] }
  end
end

describe "The True node" do
  relates "true" do
    parse { [:true] }
  end
end

describe "The False node" do
  relates "false" do
    parse { [:false] }
  end
end

describe "The Nil node" do
  relates "nil" do
    parse { [:nil] }
  end
end

describe "The String node" do
  relates '"hello, world"' do
    parse { [:string, "hello, world"] }
  end
end
 
describe "The Form node" do
  relates '()' do
    parse { [:form] }
  end

  relates '(1 ,   2 3)' do
    parse { [:form, [:number, 1], [:number, 2], [:number, 3]] }
  end

  relates '(hello world 43 "hey")' do
    parse { 
      [:form,
        [:symbol, :hello],
        [:symbol, :world],
        [:number, 43.0],
        [:string, "hey"]]
    }
  end

  relates "(hello \n\t (world 43) \"hey\")" do
    parse { 
      [:form,
        [:symbol, :hello],
        [:form,
          [:symbol, :world],
          [:number, 43.0]],
        [:string, "hey"]]
    }
  end
end

describe "The Vector node" do
  relates '[]' do
    parse { [:vector] }
  end

  relates '[1 ,   2 3]' do
    parse { [:vector, [:number, 1], [:number, 2], [:number, 3]] }
  end

  relates '[hello world 43 "hey"]' do
    parse { 
      [:vector,
        [:symbol, :hello],
        [:symbol, :world],
        [:number, 43.0],
        [:string, "hey"]]
    }
  end

  relates "[hello \n\t (world 43) \"hey\"]" do
    parse { 
      [:vector,
        [:symbol, :hello],
        [:form,
          [:symbol, :world],
          [:number, 43.0]],
        [:string, "hey"]]
    }
  end
end