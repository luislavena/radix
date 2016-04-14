require "../spec_helper"

# Silence deprecation warnings when running specs and allow
# capture them for inspection.
module Radix
  class Tree
    @show_deprecations = false
    @stderr : MemoryIO?

    def show_deprecations!
      @show_deprecations = true
    end

    private def deprecation(message)
      if @show_deprecations
        @stderr ||= MemoryIO.new
        @stderr.not_nil!.puts message
      end
    end
  end
end

module Radix
  describe Tree do
    context "a new instance" do
      it "contains a root placeholder node" do
        payload = TestPayload.new
        tree = Tree(TestPayload).new
        tree.root.should be_a(Node(TestPayload))
        tree.root.payload?.should be_falsey
        tree.root.placeholder?.should be_true
      end
    end

    describe "#add" do
      context "on a new instance" do
        it "replaces placeholder with new node" do
          payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/abc", payload
          tree.root.should be_a(Node(TestPayload))
          tree.root.placeholder?.should be_false
          tree.root.payload?.should be_truthy
          tree.root.payload.should eq(payload)
        end
      end

      context "shared root" do
        it "inserts properly adjacent nodes" do
          root_payload = TestPayload.new
          a_payload = TestPayload.new
          bc_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/a", a_payload
          tree.add "/bc", bc_payload

          # /    (:root)
          # +-bc (:bc)
          # \-a  (:a)
          tree.root.children.size.should eq(2)
          tree.root.children[0].key.should eq("bc")
          tree.root.children[0].payload.should eq(bc_payload)
          tree.root.children[1].key.should eq("a")
          tree.root.children[1].payload.should eq(a_payload)
        end

        it "inserts nodes with shared parent" do
          root_payload = TestPayload.new
          abc_payload = TestPayload.new
          axyz_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/abc", abc_payload
          tree.add "/axyz", axyz_payload

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
          root_payload = TestPayload.new
          users_payload = TestPayload.new
          products_payload = TestPayload.new
          tags_payload = TestPayload.new
          articles_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/admin/users", users_payload
          tree.add "/admin/products", products_payload
          tree.add "/blog/tags", tags_payload
          tree.add "/blog/articles", articles_payload

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
          authorizations_payload = TestPayload.new
          authorization_payload = TestPayload.new
          applications_payload = TestPayload.new
          events_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/authorizations", authorizations_payload
          tree.add "/authorizations/:id", authorization_payload
          tree.add "/applications", applications_payload
          tree.add "/events", events_payload

          # /
          # +-events               (:events)
          # +-a
          #   +-uthorizations      (:authorizations)
          #   |             \-/:id (:authorization)
          #   \-pplications        (:applications)
          tree.root.children.size.should eq(2)
          tree.root.children[1].key.should eq("a")
          tree.root.children[1].children.size.should eq(2)
          tree.root.children[1].children[0].payload.should eq(authorizations_payload)
          tree.root.children[1].children[1].payload.should eq(applications_payload)
        end

        it "supports insertion of mixed routes out of order" do
          my_repos_payload = TestPayload.new
          user_repos_payload = TestPayload.new
          user_payload = TestPayload.new
          me_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/user/repos", my_repos_payload
          tree.add "/users/:user/repos", user_repos_payload
          tree.add "/users/:user", user_payload
          tree.add "/user", me_payload

          # /user                (:me)
          #     +-/repos         (:my_repos)
          #     \-s/:user        (:user)
          #             \-/repos (:user_repos)
          tree.root.key.should eq("/user")
          tree.root.payload?.should be_truthy
          tree.root.payload.should eq(me_payload)
          tree.root.children.size.should eq(2)
          tree.root.children[0].key.should eq("/repos")
          tree.root.children[1].key.should eq("s/:user")
          tree.root.children[1].payload.should eq(user_payload)
          tree.root.children[1].children[0].key.should eq("/repos")
        end
      end

      context "dealing with duplicates" do
        it "does not allow same path be defined twice" do
          root_payload = TestPayload.new
          abc_payload = TestPayload.new
          other_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/abc", abc_payload

          expect_raises Tree::DuplicateError do
            tree.add "/", other_payload
          end

          tree.root.children.size.should eq(1)
        end
      end

      context "dealing with catch all and named parameters" do
        it "prioritizes nodes correctly" do
          root_payload = TestPayload.new
          all_payload = TestPayload.new
          products_payload = TestPayload.new
          product_payload = TestPayload.new
          edit_payload = TestPayload.new
          featured_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/*filepath", all_payload
          tree.add "/products", products_payload
          tree.add "/products/:id", product_payload
          tree.add "/products/:id/edit", edit_payload
          tree.add "/products/featured", featured_payload

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

        it "does not split named parameters across shared key" do
          tree = Tree(TestPayload).new
          tree.add "/", TestPayload.new
          tree.add "/:category", TestPayload.new
          tree.add "/:category/:subcategory", TestPayload.new

          # /                         (:root)
          # +-:category               (:category)
          #           \-/:subcategory (:subcategory)
          tree.root.children.size.should eq(1)
          tree.root.children[0].key.should eq(":category")

          # inner children
          tree.root.children[0].children.size.should eq(1)
          tree.root.children[0].children[0].key.should eq("/:subcategory")
        end

        it "does not allow different named parameters sharing same level" do
          tree = Tree(TestPayload).new
          tree.add "/", TestPayload.new
          tree.add "/:post", TestPayload.new

          expect_raises Tree::SharedKeyError do
            tree.add "/:category/:post", TestPayload.new
          end
        end
      end
    end

    describe "#find" do
      context "a single node" do
        it "does not find when using different path" do
          tree = Tree(TestPayload).new
          tree.add "/about", TestPayload.new

          result = tree.find "/products"
          result.found?.should be_false
        end

        it "finds when using matching path" do
          about_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/about", about_payload

          result = tree.find "/about"
          result.found?.should be_true
          result.key.should eq("/about")
          result.payload?.should be_truthy
          result.payload.should eq(about_payload)
        end

        it "finds when using path with trailing slash" do
          about_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/about", about_payload

          result = tree.find "/about/"
          result.found?.should be_true
          result.key.should eq("/about")
        end

        it "finds when key has trailing slash" do
          about_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/about/", about_payload

          result = tree.find "/about"
          result.found?.should be_true
          result.key.should eq("/about/")
          result.payload.should eq(about_payload)
        end
      end

      context "nodes with shared parent" do
        it "finds matching path" do
          root_payload = TestPayload.new
          abc_payload = TestPayload.new
          axyz_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/abc", abc_payload
          tree.add "/axyz", axyz_payload

          result = tree.find("/abc")
          result.found?.should be_true
          result.key.should eq("/abc")
          result.payload.should eq(abc_payload)
        end

        it "finds matching path across parents" do
          root_payload = TestPayload.new
          users_payload = TestPayload.new
          products_payload = TestPayload.new
          tags_payload = TestPayload.new
          articles_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/admin/users", users_payload
          tree.add "/admin/products", products_payload
          tree.add "/blog/tags", tags_payload
          tree.add "/blog/articles", articles_payload

          result = tree.find("/blog/tags/")
          result.found?.should be_true
          result.key.should eq("/blog/tags")
          result.payload.should eq(tags_payload)
        end
      end

      context "dealing with catch all" do
        it "finds matching path" do
          root_payload = TestPayload.new
          all_payload = TestPayload.new
          about_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/*filepath", all_payload
          tree.add "/about", about_payload

          result = tree.find("/src/file.png")
          result.found?.should be_true
          result.key.should eq("/*filepath")
          result.payload.should eq(all_payload)
        end

        it "returns catch all in parameters" do
          root_payload = TestPayload.new
          all_payload = TestPayload.new
          about_payload = TestPayload.new

          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/*filepath", all_payload
          tree.add "/about", about_payload

          result = tree.find("/src/file.png")
          result.found?.should be_true
          result.params.has_key?("filepath").should be_true
          result.params["filepath"].should eq("src/file.png")
        end

        it "returns optional catch all" do
          root_payload = TestPayload.new
          extra_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/search/*extra", extra_payload

          result = tree.find("/search")
          result.found?.should be_true
          result.key.should eq("/search/*extra")
          result.params.has_key?("extra").should be_true
          result.params["extra"].empty?.should be_true
        end

        it "does not find when catch all is not full match" do
          root_payload = TestPayload.new
          search_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/search/public/*query", search_payload

          result = tree.find("/search")
          result.found?.should be_false
        end
      end

      context "dealing with named parameters" do
        it "finds matching path" do
          root_payload = TestPayload.new
          products_payload = TestPayload.new
          product_payload = TestPayload.new
          edit_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/products", products_payload
          tree.add "/products/:id", product_payload
          tree.add "/products/:id/edit", edit_payload

          result = tree.find("/products/10")
          result.found?.should be_true
          result.key.should eq("/products/:id")
          result.payload.should eq(product_payload)
        end

        it "does not find partial matching path" do
          root_payload = TestPayload.new
          products_payload = TestPayload.new
          edit_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/products", products_payload
          tree.add "/products/:id/edit", edit_payload

          result = tree.find("/products/10")
          result.found?.should be_false
        end

        it "returns named parameters in result" do
          root_payload = TestPayload.new
          products_payload = TestPayload.new
          product_payload = TestPayload.new
          edit_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/products", products_payload
          tree.add "/products/:id", product_payload
          tree.add "/products/:id/edit", edit_payload

          result = tree.find("/products/10/edit")
          result.found?.should be_true
          result.params.has_key?("id").should be_true
          result.params["id"].should eq("10")
        end

        it "returns unicode values in parameters" do
          root_payload = TestPayload.new
          language_payload = TestPayload.new
          about_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/language/:name", language_payload
          tree.add "/language/:name/about", about_payload

          result = tree.find("/language/日本語")
          result.found?.should be_true
          result.params.has_key?("name").should be_true
          result.params["name"].should eq("日本語")
        end
      end

      context "dealing with multiple named parameters" do
        it "finds matching path" do
          root_payload = TestPayload.new
          static_page_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/:section/:page", static_page_payload

          result = tree.find("/about/shipping")
          result.found?.should be_true
          result.key.should eq("/:section/:page")
          result.payload.should eq(static_page_payload)
        end

        it "returns named parameters in result" do
          root_payload = TestPayload.new
          static_page_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/:section/:page", static_page_payload

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
          root_payload = TestPayload.new
          all_payload = TestPayload.new
          products_payload = TestPayload.new
          product_payload = TestPayload.new
          edit_payload = TestPayload.new
          featured_payload = TestPayload.new
          tree = Tree(TestPayload).new
          tree.add "/", root_payload
          tree.add "/*filepath", all_payload
          tree.add "/products", products_payload
          tree.add "/products/:id", product_payload
          tree.add "/products/:id/edit", edit_payload
          tree.add "/products/featured", featured_payload

          result = tree.find("/products/1000")
          result.found?.should be_true
          result.key.should eq("/products/:id")
          result.payload.should eq(product_payload)

          result = tree.find("/admin/articles")
          result.found?.should be_true
          result.key.should eq("/*filepath")
          result.params["filepath"].should eq("admin/articles")

          result = tree.find("/products/featured")
          result.found?.should be_true
          result.key.should eq("/products/featured")
          result.payload.should eq(featured_payload)
        end
      end
    end
  end
end
