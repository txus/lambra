require 'bundler'
Bundler::GemHelper.install_tasks

task :default => :spec

base = File.expand_path '../lib/lambra/parser', __FILE__

grammar = "#{base}/lambra.kpeg"
parser  = "#{base}/parser.rb"

file parser => grammar do
  sh "rbx -S kpeg -f -s #{base}/lambra.kpeg -o #{base}/parser.rb"
end

desc "Convert the grammar description to a parser"
task :parser => parser

desc "Run the specs (default)"
task :spec => :parser do
  sh "mspec spec"
end
