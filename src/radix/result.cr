require "./node"

module Radix
  # A Result is the comulative output of walking our [Radix tree](https://en.wikipedia.org/wiki/Radix_tree)
  # `Tree` implementation.
  #
  # It provides helpers to retrieve the information obtained from walking
  # our tree using `Tree#find`
  #
  # This information can be used to perform actions in case of the *path*
  # that was looked on the Tree was found.
  #
  # A Result is also used recursively by `Tree#find` when collecting extra
  # information like *params*.
  class Result
    getter :params
    getter! :payload

    # :nodoc:
    def initialize
      @nodes = [] of Node
      @params = {} of String => String
    end

    # Returns whatever a *payload* was found by `Tree#find` and is part of
    # the result.
    #
    # ```
    # result = Result.new
    # result.found?
    # # => false
    #
    # root = Node.new("/", :root)
    # result.use(root)
    # result.found?
    # # => true
    # ```
    def found?
      payload? ? true : false
    end

    # Returns a String built based on the nodes used in the result
    #
    # ```
    # node1 = Node.new("/", :root)
    # node2 = Node.new("about", :about)
    #
    # result = Result.new
    # result.use node1
    # result.use node2
    #
    # result.key
    # # => "/about"
    # ```
    #
    # When no node has been used, returns an empty String.
    #
    # ```
    # result = Result.new
    # result.key
    # # => ""
    # ```
    def key
      return @key if @key

      key = String.build { |io|
        @nodes.each do |node|
          io << node.key
        end
      }

      @key = key
    end

    # Adjust result information by using the details of the given `Node`.
    #
    # * Collect `Node` for future references.
    # * Use *payload* if present.
    def use(node : Node, payload = true)
      # collect nodes
      @nodes << node

      if payload && node.payload?
        @payload = node.payload
      end
    end
  end
end
