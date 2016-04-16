module Radix
  # A Node represents one element in the structure of a [Radix tree](https://en.wikipedia.org/wiki/Radix_tree)
  #
  # Carries a *payload* and might also contain references to other nodes
  # down in the organization inside *children*.
  #
  # Each node also carries a *priority* number, which might indicate the
  # weight of this node depending on characteristics like catch all
  # (globbing), named parameters or simply the size of the Node's *key*.
  #
  # Referenced nodes inside *children* can be sorted by *priority*.
  #
  # Is not expected direct usage of a node but instead manipulation via
  # methods within `Tree`.
  #
  # ```
  # node = Node.new("/", :root)
  # node.children << Node.new("a", :a)
  # node.children << Node.new("bc", :bc)
  # node.children << Node.new("def", :def)
  # node.sort!
  #
  # node.priority
  # # => 1
  #
  # node.children.map &.priority
  # # => [3, 2, 1]
  # ```
  class Node(T)
    getter key
    getter? placeholder
    property! payload : T | Nil
    property children

    # Returns the priority of the Node based on it's *key*
    #
    # This value will be directly associated to the key size or special
    # elements of it.
    #
    # * A catch all (globbed) key will receive lowest priority (`0`)
    # * A named parameter key will receive priority above catch all (`1`)
    # * Any other type of key will receive priority based on its size.
    #
    # ```
    # Node(Nil).new("a").priority
    # # => 1
    #
    # Node(Nil).new("abc").priority
    # # => 3
    #
    # Node(Nil).new("*filepath").priority
    # # => 0
    #
    # Node(Nil).new(":query").priority
    # # => 1
    # ```
    getter priority : Int32

    # Instantiate a Node
    #
    # - *key* - A `String` that represents this node.
    # - *payload* - An optional payload for this node.
    #
    # When *payload* is not supplied, ensure the type of the node is provided
    # instead:
    #
    # ```
    # # Good, node type is inferred from payload (Symbol)
    # node = Node.new("/", :root)
    #
    # # Good, node type is now Int32 but payload is optional
    # node = Node(Int32).new("/")
    #
    # # Error, node type cannot be inferred (compiler error)
    # node = Node.new("/")
    # ```
    def initialize(@key : String, @payload : T? = nil, @placeholder = false)
      @children = [] of Node(T)
      @priority = compute_priority
    end

    # Changes current *key*
    #
    # ```
    # node = Node(Nil).new("a")
    # node.key
    # # => "a"
    #
    # node.key = "b"
    # node.key
    # # => "b"
    # ```
    #
    # This will also result in a new priority for the node.
    #
    # ```
    # node = Node(Nil).new("a")
    # node.priority
    # # => 1
    #
    # node.key = "abcdef"
    # node.priority
    # # => 6
    # ```
    def key=(@key)
      @priority = compute_priority
    end

    # :nodoc:
    private def compute_priority
      reader = Char::Reader.new(@key)

      while reader.has_next?
        case reader.current_char
        when '*'
          return 0
        when ':'
          return 1
        else
          reader.next_char
        end
      end

      reader.pos
    end

    # Changes the order of Node's children based on each node priority.
    #
    # This ensures highest priority nodes are listed before others.
    #
    # ```
    # root = Node(Nil).new("/")
    # root.children << Node(Nil).new("*filepath") # node.priority => 0
    # root.children << Node(Nil).new(":query")    # node.priority => 1
    # root.children << Node(Nil).new("a")         # node.priority => 1
    # root.children << Node(Nil).new("bc")        # node.priority => 2
    # root.sort!
    #
    # root.children.map &.priority
    # # => [2, 1, 1, 0]
    # ```
    def sort!
      @children.sort_by! { |node| -node.priority }
    end
  end
end
