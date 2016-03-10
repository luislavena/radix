require "./node"
require "./result"

module Radix
  # A [Radix tree](https://en.wikipedia.org/wiki/Radix_tree) implementation.
  #
  # It allows insertion of *path* elements that will be organized inside
  # the tree aiming to provide fast retrieval options.
  #
  # Each inserted *path* will be represented by a `Node` or segmented and
  # distributed within the `Tree`.
  #
  # You can associate a *payload* at insertion which will be return back
  # at retrieval time.
  class Tree
    # :nodoc:
    class DuplicateError < Exception
      def initialize(path)
        super("Duplicate trail found '#{path}'")
      end
    end

    # Returns the root `Node` element of the Tree.
    #
    # On a new tree instance, this will be a placeholder.
    getter :root

    def initialize
      @root = Node.new("", placeholder: true)
    end

    # Inserts given *path* into the Tree
    #
    # * *path* - An `String` representing the pattern to be inserted.
    # * *payload* - Required associated element for this path.
    #
    # If no previous elements existed in the Tree, this will replace the
    # defined placeholder.
    #
    # ```
    # tree = Tree.new
    #
    # # /         (:root)
    # tree.add "/", :root
    #
    # # /         (:root)
    # # \-abc     (:abc)
    # tree.add "/abc", :abc
    #
    # # /         (:root)
    # # \-abc     (:abc)
    # #     \-xyz (:xyz)
    # tree.add "/abcxyz", :xyz
    # ```
    #
    # Nodes inside the tree will be adjusted to accomodate the different
    # segments of the given *path*.
    #
    # ```
    # tree = Tree.new
    #
    # # / (:root)
    # tree.add "/", :root
    #
    # # /                   (:root)
    # # \-products/:id      (:product)
    # tree.add "/products/:id", :product
    #
    # # /                    (:root)
    # # \-products/
    # #           +-featured (:featured)
    # #           \-:id      (:product)
    # tree.add "/products/featured", :featured
    # ```
    #
    # Catch all (globbing) and named paramters *path* will be located with
    # lower priority against other nodes.
    #
    # ```
    # tree = Tree.new
    #
    # # /           (:root)
    # tree.add "/", :root
    #
    # # /           (:root)
    # # \-*filepath (:all)
    # tree.add "/*filepath", :all
    #
    # # /           (:root)
    # # +-about     (:about)
    # # \-*filepath (:all)
    # tree.add "/about", :about
    # ```
    def add(path : String, payload)
      root = @root

      # replace placeholder with new node
      if root.placeholder?
        @root = Node.new(path, payload)
      else
        add path, payload, root
      end
    end

    private def extract_key(reader : Char::Reader) : String
      str = String.build do |str|
        while reader.has_next? && reader.current_char != '/'
          str << reader.current_char
          reader.next_char
        end
      end
      str
    end

    private def match_named_params?(path_reader, key_reader : Char::Reader) : Bool
      path_param = extract_key path_reader
      key_param = extract_key key_reader
      return path_param == key_param
    end

    # :nodoc:
    private def add(path : String, payload, node : Node)
      key_reader = Char::Reader.new(node.key)
      path_reader = Char::Reader.new(path)

      # move cursor position to last shared character between key and path
      # have to skip over any named params, breaking them up causes problems
      while path_reader.has_next? && key_reader.has_next?
        if path_reader.current_char == ':' && key_reader.current_char == ':'
          break if !match_named_params?(path_reader, key_reader)
        end
        break if path_reader.current_char != key_reader.current_char
        path_reader.next_char
        key_reader.next_char
      end

      # determine split point difference between path and key
      # compare if path is larger than key
      if path_reader.pos == 0 ||
         (path_reader.pos < path.size && path_reader.pos >= node.key.size)
        # determine if a child of this node contains the remaining part
        # of the path
        added = false

        new_key = path_reader.string.byte_slice(path_reader.pos)

        node.children.each do |child|
          # compare first character
          next unless child.key[0]? == new_key[0]?
          if child.key[0] == ':' && new_key[0] == ':'
            new_key_param = extract_key(Char::Reader.new(new_key))
            next if child.key != new_key_param
            new_key = new_key[new_key.index('/') as Int32..-1]
          end

          # when found, add to this child
          added = true
          add new_key, payload, child
          break
        end

        # if no existing child shared part of the key, add a new one
        unless added
          node.children << Node.new(new_key, payload)
        end

        # adjust priorities
        node.sort!
      elsif path_reader.pos == path.size && path_reader.pos == node.key.size
        # determine if path matches key and potentially be a duplicate
        # and raise if is the case

        if node.payload?
          raise DuplicateError.new(path)
        else
          # assign payload since this is an empty node
          node.payload = payload
        end
      elsif path_reader.pos > 0 && path_reader.pos < node.key.size
        # determine if current node key needs to be split to accomodate new
        # children nodes

        # build new node with partial key and adjust existing one
        new_key = node.key.byte_slice(path_reader.pos)
        swap_payload = node.payload? ? node.payload : nil

        new_node = Node.new(new_key, swap_payload)
        new_node.children.replace(node.children)

        # clear payload and children (this is no longer and endpoint)
        node.payload = nil
        node.children.clear

        # adjust existing node key to new partial one
        node.key = path_reader.string.byte_slice(0, path_reader.pos)
        node.children << new_node
        node.sort!

        # determine if path still continues
        if path_reader.pos < path.size
          new_key = path.byte_slice(path_reader.pos)
          node.children << Node.new(new_key, payload)
          node.sort!

          # clear payload (no endpoint)
          node.payload = nil
        else
          # this is an endpoint, set payload
          node.payload = payload
        end
      end
    end

    # Returns a `Result` instance after walking the tree looking up for
    # *path*
    #
    # It will start walking the tree from the root node until a matching
    # endpoint is found (or not).
    #
    # ```
    # tree = Tree.new
    # tree.add "/about", :about
    #
    # result = tree.find "/products"
    # result.found?
    # # => false
    #
    # result = tree.find "/about"
    # result.found?
    # # => true
    #
    # result.payload
    # # => :about
    # ```
    def find(path : String)
      result = Result.new
      root = @root

      # walk the tree from root (first time)
      find path, result, root, first: true

      result
    end

    # :nodoc:
    private def find(path : String, result : Result, node : Node, first = false)
      # special consideration when comparing the first node vs. others
      # in case of node key and path being the same, return the node
      # instead of walking character by character
      if first && (path.size == node.key.size && path == node.key) && node.payload?
        result.use node
        return
      end

      key_reader = Char::Reader.new(node.key)
      path_reader = Char::Reader.new(path)

      # walk both path and key while both have characters and they continue
      # to match. Consider as special cases named parameters and catch all
      # rules.
      while key_reader.has_next? && path_reader.has_next? &&
            (key_reader.current_char == '*' ||
            key_reader.current_char == ':' ||
            path_reader.current_char == key_reader.current_char)
        case key_reader.current_char
        when '*'
          # deal with catch all (globbing) parameter
          # extract parameter name from key (exclude *) and value from path
          name = key_reader.string.byte_slice(key_reader.pos + 1)
          value = path_reader.string.byte_slice(path_reader.pos)

          # add this to result
          result.params[name] = value

          result.use node
          return
        when ':'
          # deal with named parameter
          # extract parameter name from key (from : until / or EOL) and
          # value from path (same rules as key)
          key_size = _detect_param_size(key_reader)
          path_size = _detect_param_size(path_reader)

          # obtain key and value using calculated sizes
          # for name: skip ':' by moving one character forward and compensate
          # key size.
          name = key_reader.string.byte_slice(key_reader.pos + 1, key_size - 1)
          value = path_reader.string.byte_slice(path_reader.pos, path_size)

          # add this information to result
          result.params[name] = value

          # advance readers positions
          key_reader.pos += key_size
          path_reader.pos += path_size
        else
          # move to the next character
          key_reader.next_char
          path_reader.next_char
        end
      end

      # check if we reached the end of the path & key
      if !path_reader.has_next? && !key_reader.has_next?
        # check endpoint
        if node.payload?
          result.use node
          return
        end
      end

      # still path to walk, check for possible trailing slash or children
      # nodes
      if path_reader.has_next?
        # using trailing slash?
        if node.key.size > 0 &&
           path_reader.pos + 1 == path.size &&
           path_reader.current_char == '/'
          result.use node
          return
        end

        # not found in current node, check inside children nodes
        new_path = path_reader.string.byte_slice(path_reader.pos)
        node.children.each do |child|
          # check if child first character matches the new path
          if child.key[0]? == new_path[0]? ||
             child.key[0]? == '*' || child.key[0]? == ':'
            # consider this node for key but don't use payload
            result.use node, payload: false

            find new_path, result, child
            return
          end
        end
      end

      # key still contains characters to walk
      if key_reader.has_next?
        # determine if there is just a trailing slash?
        if key_reader.pos + 1 == node.key.size &&
           key_reader.current_char == '/'
          result.use node
          return
        end

        # check if remaining part is catch all
        if key_reader.pos < node.key.size &&
           key_reader.current_char == '/' &&
           key_reader.peek_next_char == '*'
          # skip '*'
          key_reader.next_char

          # deal with catch all, but since there is nothing in the path
          # return parameter as empty
          name = key_reader.string.byte_slice(key_reader.pos + 1)

          result.params[name] = ""

          result.use node
          return
        end
      end
    end

    # :nodoc:
    private def _detect_param_size(reader)
      # save old position
      old_pos = reader.pos

      # move forward until '/' or EOL is detected
      while reader.has_next?
        break if reader.current_char == '/'

        reader.next_char
      end

      # calculate the size
      count = reader.pos - old_pos

      # restore old position
      reader.pos = old_pos

      count
    end
  end
end
