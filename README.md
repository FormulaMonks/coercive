# Coercive

# Install

```
$ gem install coercive
```

# Usage

`Coercive` is a Ruby library to validate and coerce user input.

Define your coercion modules like this:

```ruby
require "coercive"

module CoerceFoo
  extend Coercive

  attribute :foo, string(min: 1, max: 10), required
end
```

Pass in your user input and you'll get back validated and coerced attributes:

```ruby
attributes = CoerceFoo.call("foo" => "bar")

attributes["foo"]
# => "bar"

CoerceFoo.call("foo" => "more than 10 chars long")
# => Coercive::Error: {"foo"=>"too_long"}

CoerceFoo.call("bar" => "foo is not here")
# => Coercive::Error: {"foo"=>"not_present", "bar"=>"unknown"}
```

`Coercive`'s single entry-point is the `call` method that receives a `Hash`. It will compare each key-value pair against the definitions provided by the `attribute` method.

The `attribute` functions takes three arguments:
* The first one is the name of the attribute.
* The second one is a coerce function. Coercive comes with many available, and you can always write your own.
* The third one is a fetch function, used to look up the attribute in the input `Hash`.

## Fetch functions

As you saw in the example above, `required` is one of the three fetch functions available. Let's get into each of them and how they work.

### `required`

As the name says, `Coercive` will raise an error if the input lacks the attribute, and add the `"not_present"` error code.

```ruby
CoerceFoo.call("bar" => "foo is not here")
# => Coercive::Error: {"foo"=>"not_present", "bar"=>"unknown"}
```

### `optional`

The `optional` fetch function will grab an attribute from the input, but do nothing if it's not there. Let's look again at the example above:

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, string(min: 1, max: 10), required
end

CoerceFoo.call("bar" => "foo is not here")
# => Coercive::Error: {"foo"=>"not_present", "bar"=>"unknown"}
```

The `"bar"` attribute raises an error because it's unexpected. `Coercive` is thorough when it comes to the input. To make this go away, we have to add `"bar"` as optional:

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, string(min: 1, max: 10), required
  attribute :bar, any,                     optional
end

CoerceFoo.call("bar" => "foo is not here")
# => Coercive::Error: {"foo"=>"not_present"}
```

### `implicit`

The last fetch function `Coercive` has is a handy way to set a default value when an attribute is not present in the input.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, string(min: 1, max: 10), implicit("default")
  attribute :bar, any,                     optional
end

CoerceFoo.call("bar" => "any")
# => {"foo"=>"default", "bar"=>"any"}
```

Keep in mind that your default must comply with the declared type and restrictions. In this case, `implicit("very long default value")` will raise an error because it's longer than 10 characters.

## Coercion functions

We already got a taste for the coercion functions with `string(min: 1, max:10)` and there are many more! but let's start there.

### `string(min:, max:, pattern:)`

The `string` coercion function will enforce a minimum and maximum character length, throwing `"too_short"` and `"too_long"` errors respectively if the input is not within the declared bounds.

Additionally, you can also verify your String matches a regular expression with the `pattern:` option.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, string(pattern: /\A\h+\z/), optional
end

CoerceFoo.call("foo" => "REDBEETS")
# => Coercive::Error: {"foo"=>"not_valid"}

CoerceFoo.call("foo" => "DEADBEEF")
# => {"foo"=>"DEADBEEF"}
```

### `date` and `datetime`

The `date` and `datetime` coercion functions will receive a `String` and give you `Date` and `DateTime` objects, respectively.

By default they expect an ISO 8601 string, but they provide a `format` option in case you need to parse something different, following the `strftime` format.

```ruby
module CoerceFoo
  extend Coercive

  attribute :date_foo,      date,                     optional
  attribute :american_date, date(format: "%m-%d-%Y"), optional
  attribute :datetime_foo,  datetime,                 optional
end

CoerceFoo.call("date_foo" => "1988-05-18", "datetime_foo" => "1988-05-18T21:00:00Z", "american_date" => "05-18-1988")
# => {"date_foo"=>#<Date: 1988-05-18 ((2447300j,0s,0n),+0s,2299161j)>,
#  "american_date"=>#<Date: 1988-05-18 ((2447300j,0s,0n),+0s,2299161j)>,
#  "datetime_foo"=>#<DateTime: 1988-05-18T21:00:00+00:00 ((2447300j,75600s,0n),+0s,2299161j)>}

CoerceFoo.call("date_foo" => "18th May 1988")
# => Coercive::Error: {"date_foo"=>"not_valid"}
```

### `any`

The `any` coercion function lets anything pass through. It's commonly used with the `optional` fetch function when an attribute may or many not be a part of the input.

### `member`

`member` will check that the value is one of the values of the given array.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, member(["one", "two", "three"]), optional
end

CoerceFoo.call("foo" => 4)
# => Coercive::Error: {"foo"=>"not_valid"}
```

### `integer(min:, max:)`

`integer` expects an integer value. It supports optional `min` and `max` options to check if the user input is within certain bounds.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo,        integer,                  optional
  attribute :foo_bounds, integer(min: 1, max: 10), optional
end

CoerceFoo.call("foo" => "1")
# => {"foo"=>1}

CoerceFoo.call("foo" => "bar")
# => Coercive::Error: {"foo"=>"not_valid"}

CoerceFoo.call("foo" => "1.5")
# => Coercive::Error: {"foo"=>"not_numeric"}

CoerceFoo.call("foo" => 1.5)
# => Coercive::Error: {"foo"=>"float_not_permitted"}

CoerceFoo.call("foo_bounds" => 0)
# => Coercive::Error: {"foo_bounds"=>"too_low"}

CoerceFoo.call("foo_bounds" => 11)
# => Coercive::Error: {"foo_bounds"=>"too_high"}
```

### `float(min:, max:)`

`float` expects, well, a float value. It supports optional `min` and `max` options to check if the user input is within certain bounds.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo,        float,                     optional
  attribute :foo_bounds, float(min: 1.0, max: 5.5), optional
end

CoerceFoo.call("foo" => "bar")
# => Coercive::Error: {"foo"=>"not_valid"}

CoerceFoo.call("foo" => "0.5")
# => Coercive::Error: {"foo"=>"too_low"}

CoerceFoo.call("foo" => 6.5)
# => Coercive::Error: {"foo"=>"too_high"}

CoerceFoo.call("foo" => "0.1")
# => {"foo"=>0.1}
  
CoerceFoo.call("foo" => "0.1e5")
# => {"foo"=>10000.0}
```

### `array`

The `array` coercion is interesting because it's where `Coercive` starts to shine, by letting you compose coercion functions together. Let's see:

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, array(string), optional
end

CoerceFoo.call("foo" => ["one", "two", "three"])
# => {"foo"=>["one", "two", "three"]}

CoerceFoo.call("foo" => [1, 2, 3])
# => {"foo"=>["1", "2", "3"]}

CoerceFoo.call("foo" => [nil, true])
# => {"foo"=>["", "true"]}

CoerceFoo.call("foo" => [BasicObject.new])
# => Coercive::Error: {"foo"=>["not_valid"]}
```

### `hash`

`hash` coercion let's you manipulate the key and values, similarly to how `array` does.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, hash(string(max: 3), float), optional
end

CoerceFoo.call("foo" => {"bar" => "0.1"})
# => {"foo"=>{"bar"=>0.1}}

CoerceFoo.call("foo" => {"barrrr" => "0.1"})
# => Coercive::Error: {"foo"=>{"barrrr"=>"too_long"}}
```

### `uri`

The `uri` coercion function really showcases how it's very easy to build custom logic to validate and coerce any kind of input. `uri` is meant to verify IP and URLs and has a variety of options.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, uri(string), optional
end

CoerceFoo.call("foo" => "http://github.com")
# => {"foo"=>"http://github.com"}

CoerceFoo.call("foo" => "not a url")
# => Coercive::Error: {"foo"=>"not_valid"}
```

#### Requiring a specific URI schema

The `schema_fn` option allows you to compose additional coercion functions to verify the schema.

```ruby
module CoerceFoo
  extend Coercive

  attribute :foo, uri(string, schema_fn: member(%w{http https})), optional
end

CoerceFoo.call("foo" => "https://github.com")
# => {"foo"=>"https://github.com"}

CoerceFoo.call("foo" => "ftp://github.com")
# => Coercive::Error: {"foo"=>"unsupported_schema"}
```

#### Requiring URI elements

There's a number of boolean options to enforce the presence of parts of a URI to be present. By default they're all false.

* `require_path`: for example, `"https://github.com/Theorem"`
* `require_port`: for example, `"https://github.com:433"`
* `require_user`: for example, `"https://user@github.com"`
* `require_password`: for example, `"https://:password@github.com"`
