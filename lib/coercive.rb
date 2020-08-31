require "date"
require_relative "coercive/uri"

# Public: The Coercive module implements a succinct DSL for declaring callable
# modules that will validate and coerce input data to an expected format.
module Coercive
  # Public: An error raised when a coercion cannot produce a suitable result.
  class Error < ArgumentError
    # Public: The error or errors encountered in coercing the input.
    attr_accessor :errors

    def initialize(errors)
      @errors = errors
      super(errors.inspect)
    end
  end

  # Public: Coercive the given input using the declared attribute coercions.
  #
  # input - input Hash with string keys that correspond to declared attributes.
  #
  # Returns a Hash with known attributes as string keys and coerced values.
  # Raises a Coercive::Error if the given input is not a Hash, or if there are
  # any unknown string keys in the Hash, or if the values for the known keys
  # do not pass the inner coercions for the associated declared attributes.
  def call(input)
    fail Coercive::Error.new("not_valid") unless input.is_a?(Hash)

    errors  = {}

    # Fetch attributes from the input Hash into the fetched_attrs Hash.
    #
    # Each fetch function is responsible for fetching its associated attribute
    # into the fetched_attrs Hash, or choosing not to fetch it, or choosing to
    # raise a Coercive::Error.
    #
    # These fetch functions encapsulate the respective strategies for dealing
    # with required, optional, or implicit attributes appropriately.
    fetched_attrs = {}
    attr_fetch_fns.each do |name, fetch_fn|
      begin
        fetch_fn.call(input, fetched_attrs)
      rescue Coercive::Error => e
        errors[name] = e.errors
      end
    end

    # Check for unknown names in the input (not declared, and thus not fetched).
    input.each_key do |name|
      errors[name] = "unknown" unless fetched_attrs.key?(name)
    end

    # Coercive fetched attributes into the coerced_attrs Hash.
    #
    # Each coerce function will coerce the given input value for that attribute
    # to an acceptable output value, or choose to raise a Coercive::Error.
    coerced_attrs = {}
    fetched_attrs.each do |name, value|
      coerce_fn = attr_coerce_fns.fetch(name)
      begin
        coerced_attrs[name] = coerce_fn.call(value)
      rescue Coercive::Error => e
        errors[name] = e.errors
      end
    end

    # Fail if fetching or coercion caused any errors.
    fail Coercive::Error.new(errors) unless errors.empty?

    coerced_attrs
  end

  private

  # Private: Hash with String attribute names as keys and fetch function values.
  #
  # Each coerce function will be called with one argument: the input to coerce.
  #
  # The coerce function can use any logic to convert the given input value
  # to an acceptable output value, or raise a Coercive::Error for failure.
  #
  # In practice, it is most common to use one of the builtin generator methods
  # (for example, string, or array(string)), or to use a module that was
  # declared using the Coercive DSL functions, though any custom coerce function
  # may be created and used for other behaviour, provided that it conforms to
  # the same interface.
  def attr_coerce_fns
    @attr_coerce_fns ||= {}
  end

  # Private: Hash with String attribute names as keys and fetch function values.
  #
  # Each fetch function will be called with two arguments:
  # 1 - input Hash of input attributes with String keys.
  # 2 - output Hash in which the fetched attribute should be stored (if at all).
  #
  # The fetch function can use any logic to determine whether the attribute is
  # present, whether it should be stored, whether to use an implicit default
  # value, or whether to raise a Coercive::Error to propagate failure upward.
  #
  # In practice, it is most common to use one of the builtin generator methods,
  # (required, optional, or implicit) to create the fetch function, though
  # any custom fetch function could also be used for other behaviour.
  #
  # The return value of the fetch function will be ignored.
  def attr_fetch_fns
    @attr_fetch_fns ||= {}
  end

  # Public DSL: Declare a named attribute with a coercion and fetcher mechanism.
  #
  # name               - a Symbol name for this attribute.
  # coerce_fn          - a coerce function which may be any callable object
  #                      that accepts a single argument as the input data and
  #                      returns the coerced output (or raises a Coercive::Error).
  #                      See documentation for the attr_coerce_fns method.
  # fetch_fn_generator - a callable generator that returns a fetch function when
  #                      given the String name of the attribute to be fetched.
  #                      See documentation for the attr_fetch_fns method.
  #
  # Returns the given name.
  def attribute(name, coerce_fn, fetch_fn_generator)
    str_name = name.to_s

    attr_coerce_fns[str_name] = coerce_fn
    attr_fetch_fns[str_name]  = fetch_fn_generator.call(str_name)

    name
  end

  # Public DSL: Return a coerce function that doesn't change or reject anything.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  def any
    ->(input) do
      input
    end
  end

  # Public DSL: Return a coerce function to validate that the input is a
  # member of the given set. That is, the input must be equal to at least
  # one member of the given set, or a Coercive::Error will be raised.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  #
  # set - the Array of objects to use as the set for checking membership.
  def member(set)
    ->(input) do
      fail Coercive::Error.new("not_valid") unless set.include?(input)

      input
    end
  end

  # Public DSL: Return a coerce function to coerce input to an Integer.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  def integer
    ->(input) do
      begin
        Integer(input)
      rescue TypeError, ArgumentError
        fail Coercive::Error.new("not_numeric")
      end
    end
  end

  # Public DSL: Return a coerce function to coerce input to a Float.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  def float
    ->(input) do
      begin
        Float(input)
      rescue TypeError, ArgumentError
        fail Coercive::Error.new("not_numeric")
      end
    end
  end

  # Public DSL: Return a coerce function to coerce input to a String.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  #
  # min     - if given, restrict the minimum size of the input String.
  # max     - if given, restrict the maximum size of the input String.
  # pattern - if given, enforce that the input String matches the pattern.
  def string(min: nil, max: nil, pattern: nil)
    ->(input) do
      input = begin
                String(input)
              rescue TypeError
                fail Coercive::Error.new("not_valid")
              end

      if min && min > 0
        fail Coercive::Error.new("is_empty")  if input.empty?
        fail Coercive::Error.new("too_short") if input.bytesize < min
      end

      if max && input.bytesize > max
        fail Coercive::Error.new("too_long")
      end

      if pattern && !pattern.match(input)
        fail Coercive::Error.new("not_valid")
      end

      input
    end
  end

  # Public DSL: Return a coercion function to coerce input into a Date.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  #
  # format - String following Ruby's `strftime` format to change the parsing behavior. When empty
  #          it will expect the String to be ISO 8601 compatible.
  def date(format: nil)
    ->(input) do
      input = begin
                if format
                  Date.strptime(input, format)
                else
                  Date.iso8601(input)
                end
              rescue ArgumentError
                fail Coercive::Error.new("not_valid")
              end

      input
    end
  end

  # Public DSL: Return a coercion function to coerce input into a DateTime.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  #
  # format - String following Ruby's `strftime` format to change the parsing behavior. When empty
  #          it will expect the String to be ISO 8601 compatible.
  def datetime(format: nil)
    ->(input) do
      input = begin
                if format
                  DateTime.strptime(input, format)
                else
                  DateTime.iso8601(input)
                end
              rescue ArgumentError
                fail Coercive::Error.new("not_valid")
              end

      input
    end
  end

  # Public DSL: Return a coercion function to coerce input to an Array.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  #
  # inner_coerce_fn - the coerce function to use on each element of the Array.
  def array(inner_coerce_fn)
    ->(input) do
      output = []
      errors = []
      Array(input).each do |value|
        begin
          output << inner_coerce_fn.call(value)
          errors << nil # pad the errors array with a nil element so that any
                        # errors that follow will be in the right position
        rescue Coercive::Error => e
          errors << e.errors
        end
      end

      fail Coercive::Error.new(errors) if errors.any?

      output
    end
  end

  # Public DSL: Return a coercion function to coerce input to a Hash.
  # Used when declaring an attribute. See documentation for attr_coerce_fns.
  #
  # key_coerce_fn - the coerce function to use on each key of the Hash.
  # val_coerce_fn - the coerce function to use on each value of the Hash.
  def hash(key_coerce_fn, val_coerce_fn)
    ->(input) do
      fail Coercive::Error.new("not_valid") unless input.is_a?(Hash)

      output = {}
      errors = {}
      input.each do |key, value|
        begin
          key         = key_coerce_fn.call(key)
          output[key] = val_coerce_fn.call(value)
        rescue Coercive::Error => e
          errors[key] = e.errors
        end
      end

      fail Coercive::Error.new(errors) if errors.any?

      output
    end
  end

  # Public DSL: See Coercive::URI.coerce_fn
  def uri(*args)
    Coercive::URI.coerce_fn(*args)
  end

  # Public DSL: Return a generator function for a "required" fetch function.
  # Used when declaring an attribute. See documentation for attr_fetch_fns.
  #
  # The fetcher will store the present attribute or raise a Coercive::Error.
  def required
    ->(name) do
      ->(input, fetched) do
        fail Coercive::Error.new("not_present") unless input.key?(name)

        fetched[name] = input[name]
      end
    end
  end

  # Public DSL: Return a generator function for a "optional" fetch function.
  # Used when declaring an attribute. See documentation for attr_fetch_fns.
  #
  # The fetcher will store the attribute if it is present.
  def optional
    ->(name) do
      ->(input, fetched) do
        fetched[name] = input[name] if input.key?(name)
      end
    end
  end

  # Public DSL: Return a generator function for an "implicit" fetch function.
  # Used when declaring an attribute. See documentation for attr_fetch_fns.
  #
  # The fetcher will store either the present attribute or the given default.
  #
  # default - the implicit value to use if the attribute is not present.
  def implicit(default)
    ->(name) do
      ->(attrs, fetched) do
        fetched[name] = attrs.key?(name) ? attrs[name] : default
      end
    end
  end
end