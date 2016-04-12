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
    getter :key
    getter? :placeholder
    property! payload : T
    property :children

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
    # Node.new("a").priority
    # # => 1
    #
    # Node.new("abc").priority
    # # => 3
    #
    # Node.new("*filepath").priority
    # # => 0
    #
    # Node.new(":query").priority
    # # => 1
    # ```
    @priority : Int32
    getter :priority

    # Instantiate a Node
    #
    # - *key* - A `String` that represents this node.
    # - *payload* - An Optional payload for this node.
    def initialize(@key : String, @payload = nil, @placeholder = false)
      @children = [] of Node(T)
      @priority = compute_priority
    end

    # Changes current *key*
    #
    # ```
    # node = Node.new("a")
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
    # node = Node.new("a")
    # node.priority
    # # => 1
    #
    # node.key = "abcdef"
    # node.priority
    # # => 6
    # ```
    def key=(value : String)
      @key = value
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
    # root = Node.new("/")
    # root.children << Node.new("*filepath") # node.priority => 0
    # root.children << Node.new(":query")    # node.priority => 1
    # root.children << Node.new("a")         # node.priority => 1
    # root.children << Node.new("bc")        # node.priority => 2
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
