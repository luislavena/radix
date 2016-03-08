require "../spec_helper"

module Radix
  describe Tree do
    context "a new instance" do
      it "contains a root placeholder node" do
        tree = Tree.new
        tree.root.should be_a(Node)
        tree.root.payload?.should be_falsey
        tree.root.placeholder?.should be_true
      end
    end

    describe "#add" do
      context "on a new instance" do
        it "replaces placeholder with new node" do
          tree = Tree.new
          tree.add "/abc", :abc
          tree.root.should be_a(Node)
          tree.root.placeholder?.should be_false
          tree.root.payload?.should be_truthy
          tree.root.payload.should eq(:abc)
        end
      end

      context "shared root" do
        it "inserts properly adjacent nodes" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/a", :a
          tree.add "/bc", :bc

          # /    (:root)
          # +-bc (:bc)
          # \-a  (:a)
          tree.root.children.size.should eq(2)
          tree.root.children[0].key.should eq("bc")
          tree.root.children[0].payload.should eq(:bc)
          tree.root.children[1].key.should eq("a")
          tree.root.children[1].payload.should eq(:a)
        end

        it "inserts nodes with shared parent" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/abc", :abc
          tree.add "/axyz", :axyz

          # /       (:root)
          # +-a
          #   +-xyz (:axyz)
          #   \-bc  (:abc)
          tree.root.children.size.should eq(1)
          tree.root.children[0].key.should eq("a")
          tree.root.children[0].children.size.should eq(2)
          tree.root.children[0].children[0].key.should eq("xyz")
          tree.root.children[0].children[1].key.should eq("bc")
        end

        it "inserts multiple parent nodes" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/admin/users", :users
          tree.add "/admin/products", :products
          tree.add "/blog/tags", :tags
          tree.add "/blog/articles", :articles

          # /                 (:root)
          # +-admin/
          # |      +-products (:products)
          # |      \-users    (:users)
          # |
          # +-blog/
          #       +-articles  (:articles)
          #       \-tags      (:tags)
          tree.root.children.size.should eq(2)
          tree.root.children[0].key.should eq("admin/")
          tree.root.children[0].payload?.should be_falsey
          tree.root.children[0].children[0].key.should eq("products")
          tree.root.children[0].children[1].key.should eq("users")
          tree.root.children[1].key.should eq("blog/")
          tree.root.children[1].payload?.should be_falsey
          tree.root.children[1].children[0].key.should eq("articles")
          tree.root.children[1].children[0].payload?.should be_truthy
          tree.root.children[1].children[1].key.should eq("tags")
          tree.root.children[1].children[1].payload?.should be_truthy
        end

        it "inserts multiple nodes with mixed parents" do
          tree = Tree.new
          tree.add "/authorizations", :authorizations
          tree.add "/authorizations/:id", :authorization
          tree.add "/applications", :applications
          tree.add "/events", :events

          # /
          # +-events               (:events)
          # +-a
          #   +-uthorizations      (:authorizations)
          #   |             \-/:id (:authorization)
          #   \-pplications        (:applications)
          tree.root.children.size.should eq(2)
          tree.root.children[1].key.should eq("a")
          tree.root.children[1].children.size.should eq(2)
          tree.root.children[1].children[0].payload.should eq(:authorizations)
          tree.root.children[1].children[1].payload.should eq(:applications)
        end

        it "supports insertion of mixed routes out of order" do
          tree = Tree.new
          tree.add "/user/repos", :my_repos
          tree.add "/users/:user/repos", :user_repos
          tree.add "/users/:user", :user
          tree.add "/user", :me

          # /user                (:me)
          #     +-/repos         (:my_repos)
          #     \-s/:user        (:user)
          #             \-/repos (:user_repos)
          tree.root.key.should eq("/user")
          tree.root.payload?.should be_truthy
          tree.root.payload.should eq(:me)
          tree.root.children.size.should eq(2)
          tree.root.children[0].key.should eq("/repos")
          tree.root.children[1].key.should eq("s/:user")
          tree.root.children[1].payload.should eq(:user)
          tree.root.children[1].children[0].key.should eq("/repos")
        end
      end

      context "dealing with duplicates" do
        it "does not allow same path be defined twice" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/abc", :abc

          expect_raises Tree::DuplicateError do
            tree.add "/", :other
          end

          tree.root.children.size.should eq(1)
        end
      end

      context "dealing with catch all and named parameters" do
        it "prioritizes nodes correctly" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit
          tree.add "/products/featured", :featured

          # /                      (:all)
          # +-products             (:products)
          # |        \-/
          # |          +-featured  (:featured)
          # |          \-:id       (:product)
          # |              \-/edit (:edit)
          # \-*filepath            (:all)
          tree.root.children.size.should eq(2)
          tree.root.children[0].key.should eq("products")
          tree.root.children[0].children[0].key.should eq("/")

          nodes = tree.root.children[0].children[0].children
          nodes.size.should eq(2)
          nodes[0].key.should eq("featured")
          nodes[1].key.should eq(":id")
          nodes[1].children[0].key.should eq("/edit")

          tree.root.children[1].key.should eq("*filepath")
        end
      end
    end

    describe "#find" do
      context "a single node" do
        it "does not find when using different path" do
          tree = Tree.new
          tree.add "/about", :about

          result = tree.find "/products"
          result.found?.should be_false
        end

        it "finds when using matching path" do
          tree = Tree.new
          tree.add "/about", :about

          result = tree.find "/about"
          result.found?.should be_true
          result.key.should eq("/about")
          result.payload?.should be_truthy
          result.payload.should eq(:about)
        end

        it "finds when using path with trailing slash" do
          tree = Tree.new
          tree.add "/about", :about

          result = tree.find "/about/"
          result.found?.should be_true
          result.key.should eq("/about")
        end

        it "finds when key has trailing slash" do
          tree = Tree.new
          tree.add "/about/", :about

          result = tree.find "/about"
          result.found?.should be_true
          result.key.should eq("/about/")
          result.payload.should eq(:about)
        end
      end

      context "nodes with shared parent" do
        it "finds matching path" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/abc", :abc
          tree.add "/axyz", :axyz

          result = tree.find("/abc")
          result.found?.should be_true
          result.key.should eq("/abc")
          result.payload.should eq(:abc)
        end

        it "finds matching path across parents" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/admin/users", :users
          tree.add "/admin/products", :products
          tree.add "/blog/tags", :tags
          tree.add "/blog/articles", :articles

          result = tree.find("/blog/tags/")
          result.found?.should be_true
          result.key.should eq("/blog/tags")
          result.payload.should eq(:tags)
        end
      end

      context "dealing with catch all" do
        it "finds matching path" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/about", :about

          result = tree.find("/src/file.png")
          result.found?.should be_true
          result.key.should eq("/*filepath")
          result.payload.should eq(:all)
        end

        it "returns catch all in parameters" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/about", :about

          result = tree.find("/src/file.png")
          result.found?.should be_true
          result.params.has_key?("filepath").should be_true
          result.params["filepath"].should eq("src/file.png")
        end

        it "returns optional catch all" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/search/*extra", :extra

          result = tree.find("/search")
          result.found?.should be_true
          result.key.should eq("/search/*extra")
          result.params.has_key?("extra").should be_true
          result.params["extra"].empty?.should be_true
        end

        it "does not find when catch all is not full match" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/search/public/*query", :search

          result = tree.find("/search")
          result.found?.should be_false
        end
      end

      context "dealing with named parameters" do
        it "finds matching path" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit

          result = tree.find("/products/10")
          result.found?.should be_true
          result.key.should eq("/products/:id")
          result.payload.should eq(:product)
        end

        it "does not find partial matching path" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/products", :products
          tree.add "/products/:id/edit", :edit

          result = tree.find("/products/10")
          result.found?.should be_false
        end

        it "returns named parameters in result" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit

          result = tree.find("/products/10/edit")
          result.found?.should be_true
          result.params.has_key?("id").should be_true
          result.params["id"].should eq("10")
        end

        it "returns unicode values in parameters" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/language/:name", :language
          tree.add "/language/:name/about", :about

          result = tree.find("/language/日本語")
          result.found?.should be_true
          result.params.has_key?("name").should be_true
          result.params["name"].should eq("日本語")
        end
      end

      context "dealing with multiple named parameters" do
        it "finds matching path" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/:section/:page", :static_page

          result = tree.find("/about/shipping")
          result.found?.should be_true
          result.key.should eq("/:section/:page")
          result.payload.should eq(:static_page)
        end

        it "finds post in posts" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/style/:path", :style
          tree.add "/script/:path", :script
          tree.add "/:post", :post
          tree.add "/:category/:post", :catpost
          tree.add "/:category/:subcategory/:post", :subcatpost

          result = tree.find("/example-post")
          result.found?.should be_true
          result.key.should eq("/:post")
          result.payload.should eq(:post)
        end

        it "creates children correctly" do
          tree = Radix::Tree.new
          tree.add "/", :root
          tree.add "/:foo", :foo
          tree.add "/:bar", :bar

          tree.@root.children.size.should eq(2)
          tree.@root.children[0].children.size.should eq(0)
          tree.@root.children[1].children.size.should eq(0)
        end

        it "returns named parameters in result" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/:section/:page", :static_page

          result = tree.find("/about/shipping")
          result.found?.should be_true

          result.params.has_key?("section").should be_true
          result.params["section"].should eq("about")

          result.params.has_key?("page").should be_true
          result.params["page"].should eq("shipping")
        end
      end

      context "dealing with both catch all and named parameters" do
        it "finds matching path" do
          tree = Tree.new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit
          tree.add "/products/featured", :featured

          result = tree.find("/products/1000")
          result.found?.should be_true
          result.key.should eq("/products/:id")
          result.payload.should eq(:product)

          result = tree.find("/admin/articles")
          result.found?.should be_true
          result.key.should eq("/*filepath")
          result.params["filepath"].should eq("admin/articles")

          result = tree.find("/products/featured")
          result.found?.should be_true
          result.key.should eq("/products/featured")
          result.payload.should eq(:featured)
        end
      end
    end
  end
end
