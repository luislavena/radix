# Radix Tree

[![Build Status](https://travis-ci.org/luislavena/radix.svg?branch=master)](https://travis-ci.org/luislavena/radix)

[Radix tree](https://en.wikipedia.org/wiki/Radix_tree) implementation for
Crystal language

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  radix:
    github: luislavena/radix
```

## Usage

You can associate a *payload* with each path added to the tree:

```crystal
require "radix"

tree = Radix::Tree.new
tree.add "/products", :products
tree.add "/products/featured", :featured

result = tree.find "/products/featured"

if result.found?
  puts result.payload # => :featured
end
```

You can also extract values from placeholders (as named segments or globbing):

```
tree.add "/products/:id", :product

result = tree.find "/products/1234"

if result.found?
  puts result.params["id"]? # => "1234"
end
```

Please see `Radix::Tree#add` documentation for more usage examples.

## Implementation

This project has been inspired and adapted from
[julienschmidt/httprouter](https://github.com/julienschmidt/httprouter) and
[spriet2000/vertx-http-router](https://github.com/spriet2000/vertx-http-router)
Go and Java implementations, respectively.

Changes to logic and optimizations have been made to take advantage of
Crystal's features.

## Contributing

1. Fork it ( https://github.com/luislavena/crystal-beryl/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Luis Lavena](https://github.com/luislavena) - creator, maintainer
