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

  it 'defines def' do
    '(def x 42) x'.should eval_to 42
  end

  describe '#fn' do
    it 'simply works' do
      '((fn [x] (* x x)) 3)'.should eval_to 9
    end

    it 'works with proper closure scope' do
      '(def y 2) ((fn [x] (* y x)) 3)'.should eval_to 6
    end
  end
end
