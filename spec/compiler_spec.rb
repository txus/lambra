require 'spec_helper'

describe "Environment bootstrap" do
  it 'defines println' do
    '(println "hello")'.should eval_to nil
  end

  it 'defines arithmetic functions' do
    '(+ 8 4)'.should eval_to 12
    '(- 8 4)'.should eval_to 4
    '(* 8 4)'.should eval_to 32
    '(/ 8 4)'.should eval_to 2
  end
end
