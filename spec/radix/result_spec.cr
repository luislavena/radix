require "../spec_helper"

module Radix
  describe Result do
    describe "#found?" do
      context "a new instance" do
        it "returns false when no payload is associated" do
          result = Result(Nil).new
          result.found?.should be_false
        end
      end

      context "with a payload" do
        it "returns true" do
          node = Node(Symbol).new("/", :root)
          result = Result(Symbol).new
          result.use node

          result.found?.should be_true
        end
      end
    end

    describe "#use" do
      it "uses the node payload" do
        node = Node(Symbol).new("/", :root)
        result = Result(Symbol).new
        result.payload?.should be_falsey

        result.use node
        result.payload?.should be_truthy
        result.payload.should eq(node.payload)
      end

      it "allow not to assign payload" do
        node = Node(Symbol).new("/", :root)
        result = Result(Symbol).new
        result.payload?.should be_falsey

        result.use node, payload: false
        result.payload?.should be_falsey
      end
    end
  end
end
