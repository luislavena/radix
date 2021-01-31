require "./node"

module Radix
  # Result present the output of walking our [Radix tree](https://en.wikipedia.org/wiki/Radix_tree)
  # `Radix::Tree` implementation.
  #
  # It provides helpers to retrieve the success (or failure) and the payload
  # obtained from walkin our tree using `Radix::Tree#find`
  #
  # This information can be used to perform actions in case of the *path*
  # that was looked on the Tree was found.
  #
  # A Result is also used recursively by `Radix::Tree#find` when collecting
  # extra information like *params*.
  class Result(T)
    @key : String?

    getter params
    getter! payload : T?

    # :nodoc:
    def initialize
      @params = {} of String => String
    end

    # Returns whatever a *payload* was found by `Tree#find` and is part of
    # the result.
    #
    # ```
    # result = Radix::Result(Symbol).new
    # result.found?
    # # => false
    #
    # root = Radix::Node(Symbol).new("/", :root)
    # result.use(root)
    # result.found?
    # # => true
    # ```
    def found?
      payload? ? true : false
    end

    # Adjust result information by using the details of the given `Node`.
    #
    # * Collect `Node` for future references.
    # * Use *payload* if present.
    def use(node : Node(T), payload = true)
      if payload && node.payload?
        @payload = node.payload
      end
    end
  end
end
