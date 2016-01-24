require "../spec_helper"

module Radix
  describe Node do
    describe "#key=" do
      it "accepts change of key after initialization" do
        node = Node.new("abc")
        node.key.should eq("abc")

        node.key = "xyz"
        node.key.should eq("xyz")
      end
    end

    describe "#payload" do
      it "accepts any form of payload" do
        node = Node.new("abc", :payload)
        node.payload?.should be_truthy
        node.payload.should eq(:payload)

        node = Node.new("abc", 1_000)
        node.payload?.should be_truthy
        node.payload.should eq(1_000)
      end

      it "makes optional to provide a payload" do
        node = Node.new("abc")
        node.payload?.should be_falsey
      end
    end

    describe "#priority" do
      it "calculates it based on key size" do
        node = Node.new("a")
        node.priority.should eq(1)

        node = Node.new("abc")
        node.priority.should eq(3)
      end

      it "returns zero for catch all (globbed) key" do
        node = Node.new("*filepath")
        node.priority.should eq(0)

        node = Node.new("/src/*filepath")
        node.priority.should eq(0)
      end

      it "returns one for keys with named parameters" do
        node = Node.new(":query")
        node.priority.should eq(1)

        node = Node.new("/search/:query")
        node.priority.should eq(1)
      end

      it "changes when key changes" do
        node = Node.new("a")
        node.priority.should eq(1)

        node.key = "abc"
        node.priority.should eq(3)

        node.key = "*filepath"
        node.priority.should eq(0)

        node.key = ":query"
        node.priority.should eq(1)
      end
    end

    describe "#sort!" do
      it "orders children by priority" do
        root = Node.new("/")
        node1 = Node.new("a")
        node2 = Node.new("bc")
        node3 = Node.new("def")

        root.children.push(node1, node2, node3)
        root.sort!

        root.children[0].should eq(node3)
        root.children[1].should eq(node2)
        root.children[2].should eq(node1)
      end

      it "orders catch all and named parameters lower than others" do
        root = Node.new("/")
        node1 = Node.new("*filepath")
        node2 = Node.new("abc")
        node3 = Node.new(":query")

        root.children.push(node1, node2, node3)
        root.sort!

        root.children[0].should eq(node2)
        root.children[1].should eq(node3)
        root.children[2].should eq(node1)
      end
    end
  end
end
