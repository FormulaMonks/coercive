require "ipaddr"
require "uri"

module Coercive
  module URI
    # Public DSL: Return a coercion function to coerce input to a URI.
    # Used when declaring an attribute. See documentation for attr_coerce_fns.
    #
    # string_coerce_fn - the string coerce function used to coerce the URI
    # schema_fn        - the optional function used to coerce the schema
    # require_path     - set true to make the URI path a required element
    # require_port     - set true to make the URI port a required element
    # require_user     - set true to make the URI user a required element
    # require_password - set true to make the URI password a required element
    def self.coerce_fn(string_coerce_fn, schema_fn: nil, require_path: false,
            require_port: false, require_user: false, require_password: false)
      ->(input) do
        uri = begin
          ::URI.parse(string_coerce_fn.call(input))
        rescue ::URI::InvalidURIError
          fail Coercive::Error.new("not_valid")
        end

        fail Coercive::Error.new("no_host") unless uri.host
        fail Coercive::Error.new("no_path") if require_path && uri.path.empty?
        fail Coercive::Error.new("no_port") if require_port && !uri.port
        fail Coercive::Error.new("no_user") if require_user && !uri.user
        fail Coercive::Error.new("no_password") if require_password && !uri.password

        if schema_fn
          begin
            schema_fn.call(uri.scheme)
          rescue Coercive::Error
            fail Coercive::Error.new("unsupported_schema")
          end
        end

        uri.to_s
      end
    end
  end
end