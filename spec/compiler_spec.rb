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

  describe 'fn' do
    it 'simply works' do
      '((fn [x] (* x x)) 3)'.should eval_to 9
    end

    it 'works with proper closure scope' do
      '(def y 2) ((fn [x] (* y x)) 3)'.should eval_to 6
    end
  end

  describe 'let' do
    it 'simply works' do
      '(let [x 2 y 3] (* x y))'.should eval_to 6
    end
  end

  describe 'spawn' do
    it 'spawns a new process' do
      '(spawn (fn [] (sleep 10)))'.should eval_to_kind_of(Integer)
    end
  end

  describe 'self' do
    it 'is bound to the current process pid' do
      'self'.should eval_to_kind_of(Integer)
    end
  end

  describe 'match' do
    it 'can match literal values' do
      %q{
      (match 42
        (42 "foo"))
      }.should eval_to "foo"
    end

    it 'can have a bound catch all pattern' do
      %q{
      (match 42
        (99 99)
        (x (+ x 3)))
      }.should eval_to 45
    end

    it 'can have an unbound catch all pattern' do
      %q{
      (match 42
        (_ 99))
      }.should eval_to 99
    end

    it 'can fail the pattern match' do
      proc {
        Lambra::Compiler.eval %q{
          (match 42
            (99 99))
        }
      }.should raise_error ArgumentError
    end
  end

  describe 'receive' do
    it 'blocks until a new message arrives' do
      %Q{
        (let [echo (spawn
                     (fn []
                       (receive [pid msg] (send pid self msg))))]
          (send echo self "hello world"))
        (receive [pid msg] msg)
      }.should eval_to "hello world"
    end
  end
end
