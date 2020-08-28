require_relative "../lib/coercive"
require "minitest/autorun"
require "bigdecimal"

describe "Coercive" do
  def assert_coercion_error(errors)
    yield
    assert false, "should have raised a Coercive::Error"
  rescue Coercive::Error => e
    assert_equal errors, e.errors
  end

  describe "required" do
    it "errors when the attribute isn't present" do
      coercion = Module.new do
        extend Coercive

        attribute :foo, any, required
        attribute :bar, any, required
        attribute :baz, any, required
      end

      expected_errors = { "foo" => "not_present", "baz" => "not_present" }

      assert_coercion_error(expected_errors) { coercion.call("bar" => "red") }
    end
  end

  describe "implicit" do
    it "uses a default value when the attribute isn't present" do
      coercion = Module.new do
        extend Coercive

        attribute :foo, any, implicit("black")
        attribute :bar, any, implicit("grey")
        attribute :baz, any, implicit("blue")
      end

      expected = { "foo" => "black", "bar" => "red", "baz" => "blue" }

      assert_equal expected, coercion.call("bar" => "red")
    end
  end

  describe "optional" do
    it "omits the attribute in the output when not present in the input" do
      coercion = Module.new do
        extend Coercive

        attribute :foo, any, optional
        attribute :bar, any, optional
        attribute :baz, any, optional
      end

      expected = { "bar" => "red" }

      assert_equal expected, coercion.call("bar" => "red")
    end
  end

  describe "any" do
    it "accepts any input" do
      coercion = Module.new do
        extend Coercive

        attribute :foo, any, required
      end

      [true, nil, "red", 88, [1, 2, 3]].each do |value|
        expected = { "foo" => value }

        assert_equal expected, coercion.call("foo" => value)
      end
    end
  end

  describe "member" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :foo, member([nil, "red", "black"]), required
      end
    end

    it "accepts any input in the set" do
      [nil, "red", "black"].each do |value|
        expected = { "foo" => value }

        assert_equal expected, @coercion.call("foo" => value)
      end
    end

    it "errors on any other input in the set" do
      [true, "blue", 88, [1, 2, 3]].each do |bad|
        expected_errors = { "foo" => "not_valid" }

        assert_coercion_error(expected_errors) { @coercion.call("foo" => bad) }
      end
    end
  end

  describe "float" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :foo, float, required
      end
    end

    it "coerces the input value to a float" do
      fixnum     = 2
      rational   = 2 ** -2
      bignum     = 2 ** 64
      bigdecimal = BigDecimal("0.1")

      [fixnum, rational, bignum, bigdecimal].each do |value|
        attributes = { "foo" => value }

        expected = { "foo" => Float(value) }

        assert_equal expected, @coercion.call(attributes)
        assert_equal Float,    @coercion.call(attributes)["foo"].class
      end
    end

    it "errors when the input value can't be coerced to a float" do
      [true, nil, "red", [1, 2, 3]].each do |bad|
        expected_errors = { "foo" => "not_numeric" }

        assert_coercion_error(expected_errors) { @coercion.call("foo" => bad) }
      end
    end
  end

  describe "string" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :foo,   string,                     optional
        attribute :bar,   string,                     optional
        attribute :baz,   string,                     optional
        attribute :min,   string(min: 4),             optional
        attribute :max,   string(max: 6),             optional
        attribute :sized, string(min: 4, max: 6),     optional
        attribute :hex_a, string(pattern: /\A\h+\z/), optional
        attribute :hex_b, string(pattern: /\A\h+\z/), optional
      end
    end

    it "coerces the input value to a string" do
      attributes = { "foo" => false, "bar" => 88, "baz" => "string" }

      expected = { "foo" => "false", "bar" => "88", "baz" => "string" }

      assert_equal expected, @coercion.call(attributes)
    end

    it "errors if the input is longer than the declared maximum size" do
      attributes = {
        "min" => "this will be okay",
        "max" => "this is too long",
        "sized" => "this also",
      }

      expected_errors = { "max" => "too_long", "sized" => "too_long" }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end

    it "errors if the input is shorter than the declared minimum size" do
      attributes = {
        "min"   => "???",
        "max"   => "???",
        "sized" => "???",
      }

      expected_errors = { "min" => "too_short", "sized" => "too_short" }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end

    it "errors if the input does not match the declared pattern" do
      attributes = { "hex_a" => "DEADBEEF", "hex_b" => "REDBEETS" }

      expected_errors = { "hex_b" => "not_valid" }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end

    it "checks size of the input after coercing to a string" do
      attributes = { "max" => 1234567, "min" => 89 }

      expected_errors = { "max" => "too_long", "min" => "too_short" }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end
  end

  describe "date" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :date, date, required
      end
    end

    it "coerces a string into a Date object" do
      attributes = { "date" => "1988-05-18" }

      expected = { "date" => Date.new(1988, 5, 18) }

      assert_equal expected, @coercion.call(attributes)
    end

    it "errors if the input isn't ISO 8601 format" do
      attributes = { "date" => "18th May 1988" }

      expected_errors = { "date" => "not_valid" }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end
  end

  describe "datetime" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :datetime, datetime, required
      end
    end

    it "coerces a string into a DateTime object" do
      attributes = { "datetime" => "1988-05-18T21:00:00Z" }

      expected = { "datetime" => DateTime.new(1988, 5, 18, 21, 00, 00) }

      assert_equal expected, @coercion.call(attributes)
    end

    it "honors the timezone" do
      attributes = { "datetime" => "1988-05-18T21:00:00-0300" }

      expected = { "datetime" => DateTime.new(1988, 5, 18, 21, 00, 00, "-03:00") }

      assert_equal expected, @coercion.call(attributes)
    end

    it "errors if the input isn't ISO 8601 format" do
      attributes = { "datetime" => "18th May 1988" }

      expected_errors = { "datetime" => "not_valid" }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end
  end

  describe "array" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :strings, array(string), required
      end
    end

    it "coerces a array attribute input value to an array" do
      attributes = { "strings" => "foo" }

      expected = { "strings" => ["foo"] }

      assert_equal expected, @coercion.call(attributes)
    end

    it "coerces a array attribute input's elements with the inner coercion" do
      attributes = { "strings" => ["", 88, true] }

      expected = { "strings" => ["", "88", "true"] }

      assert_equal expected, @coercion.call(attributes)
    end

    it "collects errors from an array attribute input's elements" do
      bad        = BasicObject.new
      attributes = { "strings" => ["ok", bad, "ok"] }

      expected_errors = { "strings" => [nil, "not_valid", nil] }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end
  end

  describe "hash" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :strings, hash(string(max: 6), string), required
      end
    end

    it "errors when a hash attribute input value isn't a hash" do
      [nil, true, "foo", []].each do |invalid|
        attributes = { "strings" => invalid }

        expected_errors = { "strings" => "not_valid" }

        assert_coercion_error(expected_errors) { @coercion.call(attributes) }
      end
    end

    it "coerces a hash attribute keys and values with the inner coercions" do
      attributes = { "strings" => { false => nil } }

      expected = { "strings" => { "false" => "" } }

      assert_equal expected, @coercion.call(attributes)
    end

    it "collects errors from a hash attribute input's keys and values" do
      bad        = BasicObject.new
      attributes = { "strings" => { "foo" => bad, "food_truck" => "ok" } }

      expected_errors = {
        "strings" => { "foo" => "not_valid", "food_truck" => "too_long" }
      }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end
  end

  describe "with various declared attributes" do
    before do
      @coercion = Module.new do
        extend Coercive

        attribute :req_hash,
          hash(string(max: 6), string),
          required

        attribute :opt_string,
          string(min: 4, max: 6),
          optional

        attribute :imp_array,
          array(string),
          implicit(["default"])
      end

      @valid_attributes = {
        "req_hash"   => { "one" => "red", "two" => "blue" },
        "opt_string" => "apple",
        "imp_array"  => ["foo", "bar", "baz"],
      }
    end

    it "returns valid attributes without changing them" do
      assert_equal @valid_attributes, @coercion.call(@valid_attributes)
    end

    it "errors when given an undeclared attribute" do
      attributes = @valid_attributes.merge("bogus" => true)

      expected_errors = { "bogus" => "unknown" }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end

    it "collects errors from all fetchers and coercions before reporting" do
      attributes = {
        "bogus"      => "bogus",
        "opt_string" => "bar",
        "imp_array"  => ["ok", BasicObject.new, "ok"],
      }

      expected_errors = {
        "bogus"      => "unknown",
        "req_hash"   => "not_present",
        "opt_string" => "too_short",
        "imp_array"  => [nil, "not_valid", nil],
      }

      assert_coercion_error(expected_errors) { @coercion.call(attributes) }
    end

    it "errors if given input that is not a Hash" do
      assert_coercion_error("not_valid") { @coercion.call(nil) }
      assert_coercion_error("not_valid") { @coercion.call(88) }
      assert_coercion_error("not_valid") { @coercion.call([]) }
    end
  end
end