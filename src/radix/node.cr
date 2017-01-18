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
  # node = Radix::Node.new("/", :root)
  # node.children << Radix::Node.new("a", :a)
  # node.children << Radix::Node.new("bc", :bc)
  # node.children << Radix::Node.new("def", :def)
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
    # * A catch all (globbed) key will receive lowest priority (`-2`)
    # * A named parameter key will receive priority above catch all (`-1`)
    # * Any other type of key will receive priority based on its size.
    #
    # ```
    # Radix::Node(Nil).new("a").priority
    # # => 1
    #
    # Radix::Node(Nil).new("abc").priority
    # # => 3
    #
    # Radix::Node(Nil).new("*filepath").priority
    # # => -2
    #
    # Radix::Node(Nil).new(":query").priority
    # # => -1
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
    # node = Radix::Node.new("/", :root)
    #
    # # Good, node type is now Int32 but payload is optional
    # node = Radix::Node(Int32).new("/")
    #
    # # Error, node type cannot be inferred (compiler error)
    # node = Radix::Node.new("/")
    # ```
    def initialize(@key : String, @payload : T? = nil, @placeholder = false)
      @children = [] of Node(T)
      @priority = compute_priority
    end

    # Changes current *key*
    #
    # ```
    # node = Radix::Node(Nil).new("a")
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
    # node = Radix::Node(Nil).new("a")
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
          return -2
        when ':'
          return -1
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
    # root = Radix::Node(Nil).new("/")
    # root.children << Radix::Node(Nil).new("*filepath") # node.priority => -2
    # root.children << Radix::Node(Nil).new(":query")    # node.priority => -1
    # root.children << Radix::Node(Nil).new("a")         # node.priority => 1
    # root.children << Radix::Node(Nil).new("bc")        # node.priority => 2
    # root.sort!
    #
    # root.children.map &.priority
    # # => [2, 1, -1, -2]
    # ```
    def sort!
      @children.sort_by! { |node| -node.priority }
    end
  end
end
