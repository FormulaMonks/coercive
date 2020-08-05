require "ipaddr"
require "uri"

module Coercive
  module URI
    # Setting this `true` allows outbound connections to private IP addresses,
    # bypassing the security check that the IP address is public. This is designed
    # to be used in devlopment so that the tests can connect to local services.
    #
    # This SHOULD NOT be set in PRODUCTION.
    ALLOW_PRIVATE_IP_CONNECTIONS =
      ENV.fetch("ALLOW_PRIVATE_IP_CONNECTIONS", "").downcase == "true"

    PRIVATE_IP_RANGES = [
      IPAddr.new("0.0.0.0/8"),       # Broadcasting to the current network. RFC 1700.
      IPAddr.new("10.0.0.0/8"),      # Local private network. RFC 1918.
      IPAddr.new("127.0.0.0/8"),     # Loopback addresses to the localhost. RFC 990.
      IPAddr.new("169.254.0.0/16"),  # link-local addresses between two hosts on a single link. RFC 3927.
      IPAddr.new("172.16.0.0/12"),   # Local private network. RFC 1918.
      IPAddr.new("192.168.0.0/16"),  # Local private network. RFC 1918.
      IPAddr.new("198.18.0.0/15"),   # Testing of inter-network communications between two separate subnets. RFC 2544.
      IPAddr.new("198.51.100.0/24"), # Assigned as "TEST-NET-2" in RFC 5737.
      IPAddr.new("203.0.113.0/24"),  # Assigned as "TEST-NET-3" in RFC 5737.
      IPAddr.new("240.0.0.0/4"),     # Reserved for future use, as specified by RFC 6890
      IPAddr.new("::1/128"),         # Loopback addresses to the localhost. RFC 5156.
      IPAddr.new("2001:20::/28"),    # Non-routed IPv6 addresses used for Cryptographic Hash Identifiers. RFC 7343.
      IPAddr.new("fc00::/7"),        # Unique Local Addresses (ULAs). RFC 1918.
      IPAddr.new("fe80::/10"),       # link-local addresses between two hosts on a single link. RFC 3927.
    ].freeze

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
        fail Coercive::Error.new("not_resolvable") unless resolvable_public_ip?(uri) || ALLOW_PRIVATE_IP_CONNECTIONS
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

    # Internal: Return true if the given URI is resolvable to a non-private IP.
    #
    # uri - the URI to check.
    def self.resolvable_public_ip?(uri)
      begin
        _, _, _, *resolved_addresses = Socket.gethostbyname(uri.host)
      rescue SocketError
        return false
      end

      resolved_addresses.none? do |bytes|
        ip = ip_from_bytes(bytes)

        ip.nil? || PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
      end
    end

    # Internal: Return an IPAddr built from the given address bytes.
    #
    # bytes - the binary-encoded String returned by Socket.gethostbyname.
    def self.ip_from_bytes(bytes)
      octets = bytes.unpack("C*")

      string =
        if octets.length == 4 # IPv4
          octets.join(".")
        else # IPv6
          octets.map { |i| "%02x" % i }.each_slice(2).map(&:join).join(":")
        end

      IPAddr.new(string)
    rescue IPAddr::InvalidAddressError
      nil
    end
  end
end