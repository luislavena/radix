require "spec"
require "../src/radix"

class TestPayload
  @data : Hash(String, String)

  def initialize
    @data = {"name": "Kemal", "type": "micro web framework"}
  end
end
