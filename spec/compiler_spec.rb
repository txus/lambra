require 'spec_helper'

describe "Environment bootstrap" do
  describe 'println' do
    Lambra::CodeLoader.evaluate '(println "hello")'
  end
end
