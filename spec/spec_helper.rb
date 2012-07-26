spec_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.expand_path(File.join(spec_dir, '../lib'))

$:.unshift(lib_dir)
$:.uniq!

require 'autoparse'
require 'json'

module JSONMatchers
  class EqualsJson
    def initialize(expected)
      @expected = JSON.parse(expected)
    end
    def matches?(target)
      @target = JSON.parse(target)
      @target.eql?(@expected)
    end
    def failure_message
      "expected #{@target.inspect} to be #{@expected}"
    end
    def negative_failure_message
      "expected #{@target.inspect} not to be #{@expected}"
    end
  end
  
  def be_json(expected)
    EqualsJson.new(expected)
  end
end