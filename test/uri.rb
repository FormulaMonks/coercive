require "minitest/autorun"

require_relative "../lib/coercive"
require_relative "../lib/coercive/uri"

describe "Coercive::URI" do
  def assert_coercion_error(errors)
    yield
    assert false, "should have raised a Coercive::Error"
  rescue Coercive::Error => e
    assert_equal errors, e.errors
  end

  before do
    @coercion = Module.new do
      extend Coercive

      attribute :any,   uri(string),                   optional
      attribute :min,   uri(string(min: 13)),          optional
      attribute :max,   uri(string(max: 17)),          optional
      attribute :sized, uri(string(min: 13, max: 17)), optional

      attribute :schema,
        uri(string(min: 1, max: 255), schema_fn: member(%w{http})),
        optional

      attribute :require_path,
        uri(string(min: 1, max: 255), require_path: true),
        optional

      attribute :require_port,
        uri(string(min: 1, max: 255), require_port: true),
        optional

      attribute :require_user,
        uri(string(min: 1, max: 255), require_user: true),
        optional

      attribute :require_password,
        uri(string(min: 1, max: 255), require_password: true),
        optional
    end
  end

  it "coerces a valid string to a URI" do
    attributes = {
      "any" => "http://user:pass@www.example.com:1234/path"
    }

    assert_equal attributes, @coercion.call(attributes)
  end

  it "errors if input is an invalid URI" do
    attributes = { "any" => "%" }

    expected_errors = { "any" => "not_valid" }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "errors if the input is longer than the declared maximum size" do
    attributes = {
      "min"   => "http://foo.com",
      "max"   => "http://long.url.com",
      "sized" => "http://way.too.long.com",
    }

    expected_errors = { "max" => "too_long", "sized" => "too_long" }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "errors if the input is shorter than the declared minimum size" do
    attributes = {
      "min"   => "http://a.com",
      "max"   => "http://bar.com",
      "sized" => "http://c.com"
    }

    expected_errors = { "min" => "too_short", "sized" => "too_short" }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "errors if the URI is an empty string" do
    attributes      = { "schema" => "" }
    expected_errors = { "schema" => "is_empty" }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "errors if no host" do
    attributes = { "any" => "http://" }

    expected_errors = { "any" => "no_host" }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "errors if schema is not supported" do
    attributes = { "schema" => "foo://example.com" }

    expected_errors = { "schema" => "unsupported_schema" }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "errors if required elements are not provided" do
    attributes = {
      "require_path"     => "foo://example.com",
      "require_port"     => "foo://example.com",
      "require_user"     => "foo://example.com",
      "require_password" => "foo://example.com",
    }

    expected_errors = {
      "require_path"     => "no_path",
      "require_port"     => "no_port",
      "require_user"     => "no_user",
      "require_password" => "no_password",
    }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "allows a URI host to be an IP" do
    attributes = { "schema" => "http://8.8.8.8/path" }

    assert_equal attributes, @coercion.call(attributes)
  end

  it "allows a URI with no explicit path component" do
    attributes = { "schema" => "http://www.example.com" }

    assert_equal attributes, @coercion.call(attributes)
  end

  it "errors for a string that does not pass URI.parse" do
    attributes = { "schema" => "\\" }
    expected_errors = { "schema" => "not_valid" }

    assert_coercion_error(expected_errors) { @coercion.call(attributes) }
  end

  it "errors for a URL that passes URI.parse, but is ill-formed" do
    attributes = { "schema" => "http:example.com/path" }

    begin
      @coercion.call(attributes)
      assert false, "should have raised a Coercive::Error"
    rescue Coercive::Error => e
      assert !e.errors["schema"].empty?, "should have a schema error"
    end
  end
end
