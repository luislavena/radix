require "../spec_helper"

module Radix
  describe Result do
    describe "#found?" do
      context "a new instance" do
        it "returns false when no payload is associated" do
          result = Result.new
          result.found?.should be_false
        end
      end

      context "with a payload" do
        it "returns true" do
          node = Node.new("/", :root)
          result = Result.new
          result.use node

          result.found?.should be_true
        end
      end
    end

    describe "#key" do
      context "a new instance" do
        it "returns an empty key" do
          result = Result.new
          result.key.should eq("")
        end
      end

      context "given one used node" do
        it "returns the node key" do
          node = Node.new("/", :root)
          result = Result.new
          result.use node

          result.key.should eq("/")
        end
      end

      context "using multiple nodes" do
        it "combines the node keys" do
          node1 = Node.new("/", :root)
          node2 = Node.new("about", :about)
          result = Result.new
          result.use node1
          result.use node2

          result.key.should eq("/about")
        end
      end
    end

    describe "#use" do
      it "uses the node payload" do
        node = Node.new("/", :root)
        result = Result.new
        result.payload?.should be_falsey

        result.use node
        result.payload?.should be_truthy
        result.payload.should eq(node.payload)
      end
    end
  end
end
