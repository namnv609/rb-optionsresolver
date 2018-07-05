# Rb OptionsResolver - Symfony OptionsResolver for Ruby

> The Rb OptionsResolver library is Symfony OptionsResolver for Ruby. It allows you to create an options system with required options, defaults, validation (type, value), normalization and more.

## Installation

```
$ gem install rb-optionsresolver
```

## Usage

To use OptionsResolver:

```ruby
require "rb-optionsresolver"
```

Imagine you have a `Mailer` class which has four options: `host`, `username`, `password` and `port`:

```ruby
class Mailer
  def initialize options
    @options = options
  end
end
```

When accessing the `@options`, you need to add a lot of boilerplate code to check which options are set:

```ruby
class Mailer
  # ...

  def send_mail from, to
    mail = ...
    mail.set_host @options[:host] ? @options[:host] : "smtp.example.com"
    mail.set_username @options[:username] ? @options[:username] : "user"
    mail.set_password @options[:password] ? @options[:password] : "pa$$word"
    mail.set_port @options[:port] ? @options[:port] : 25

    # ...
  end
end
```

This boilerplate is hard to read and repetitive. Also, the default values of the options are buried in the business logic of your code. Use code below to fix that:

```ruby
class Mailer
  def initialize options
    default_options = {
      host: "smtp.example.com",
      username: "user"
    }

    @options = [*default_options, *options].to_h
  end
end
```

Now all four options are guaranteed to be set. But what happens if the user of the `Mailer` class makes a mistake?

```ruby
mailer_opts = {
  usernme: "johndoe" # usernme misspelled (instead of username)
}
mailer = Mailer.new mailer_opts
```

No error will be shown. In the best case, the bug will appear during testing, but the developer will spend time looking for the problem. In the worst case, the bug might not appear until it's deployed to the live system.

Fortunately, the `OptionsResolver` class helps you to fix this problem:

```ruby
class Mailer
  def initialize options
    resolver = OptionsResolver.new
    resolver.set_defaults({
      host: "smtp.example.com",
      username: "user",
      password: "pa$$word",
      port: 25
    })

    @options = resolver.resolve options
  end
end
```

Like before, all options will be guaranteed to be set. Additionally, an `UndefinedOptions` is thrown if an unknown option is passed:

```ruby
mailer_opts = {usernme: "johndoe"}
mailer = Mailer.new mailer_opts

# The option "usernme" does not exist.
# Know options are: "host", "username", "password", "port" (UndefinedOptions)
```

The rest of your code can access the values of the options without boilerplate code:

```ruby
class Mailer
  # ...

  def send_mail from, to
    mail = ...

    mail.set_host @options[:host]
    mail.set_username @options[:username]
    mail.set_password @options[:password]
    mail.set_port @options[:port]
  end
end
```

### Required Options

If an option must be set by the caller, pass that option to `set_required()`. For example, to make the `host` option required, you can do:

```ruby
class Mailer
  def initialize options
    resolver = OptionsResolver.new
    resolver.set_required "host"

    @options = resolver.resolve options
  end
end
```

If you omit a required option, a `MissingOptions` will be thrown:

```ruby
mailer = Mailer.new

#  The required options "host" is missing. (MissingOptions)
```

The `set_required()` method accepts a single name or an array of option names if you have more than one required option:

```ruby
class Mailer
  # ...
  resolver.set_required %w(host username password)
end
```

Use `is_required?()` to find out if an option is required. You can use `get_required_options()` to retrieve the names of all required options:

```
required_options = resolver.get_required_options()
```

If you want to check whether a required option is still missing from the default options, you can use `is_missing?()`. The difference between this and `is_required?()` is that this method will return false if a required option has already been set:

```ruby
# ...
resolver.is_required? "host" # true
resolver.is_missing? "host" # true
resolver.set_default "host", "smtp.example.com"
resolver.is_required? "host" # true
resolver.is_missing? "host" # false
```

The method `get_missing_options()` lets you access the names of all missing options.

### Type Validation

You can run additional checks on the options to make sure they were passed correctly. To validate the types of the options, call `set_allowed_types()`:

```ruby
# ...
# specify one allowed type
resolver.set_allowed_types "port", "int"
```

> **TODO**: Specify multiple allowed types and can pass fully qualified class names.

You can pass any type for which an:

* `integer` (`int`)
* `string` (`str`)
* `array` (`arr`)
* `boolean` (`bool`)
* `float`
* `hash`
* `symbol` (`sym`)
* `range`
* `regexp`
* `proc`

If you pass an invalid option now, an `InvalidOptions` is thrown:

```ruby
mailer_opts = {
  port: "465"
}
mailer = Mailer.new mailer_opts

#  The option "port" with "465" is expected to be of type "int" (InvalidOptions)
```

> **TODO**: In sub-classes, you can use `add_allowed_types()` to add additional allowed types without erasing the ones already set.

### Value Validation

Some options can only take one of a fixed list of predefined values. For example, suppose the `Mailer` class has a `transport` option which can be one of `sendmail`, `mail` and `smtp`. Use the method `set_allowed_values()` to verify that the passed option contains one of these values:

```ruby
class Mailer
  # ...
  resolver.set_default("transport", "sendmail")
    .set_allowed_values("transport", %w(sendmail mail smtp))
end
```

If you pass an invalid transport, an `InvalidOptions` is thrown:

```ruby
mailer_opts = {
  transport: "send-mail"
}
mailer = Mailer.new mailer_opts

# The option "transport" with value "send-mail" is invalid.
# Accepted values are "sendmail", "mail", "smtp" (RuntimeError)
```

For options with more complicated validation schemes, pass a proc (or lambda) which returns `true` for acceptable values and `false` for invalid values:

```ruby
# ...
resolver.set_allowed_values "transport", Proc.new{|transport|
  # return true or false
  %w(sendmail mail smtp).include? transport
}
```

> **TODO**: In sub-classes, you can use `add_allowed_values()` to add additional allowed values without erasing the ones already set.

### Option Normalization


Sometimes, option values need to be normalized before you can use them. For instance, assume that the `host` should always start with `http://`. To do that, you can write normalizers. Normalizers are executed after validating an option. You can configure a normalizer by calling `set_normailizer()`:

```ruby
# ...
resolver.set_normailizer "host", lambda{|options, host|
  host = "http://#{host}" unless /^https?\:\/\//.match? host
  host
}
```

The normalizer receives the actual `host` and returns the normalized form. You see that the proc (or lambda) also takes an `options` parameter. This is useful if you need to use other options during normalization:

```ruby
# ...
.set_normalizer("host", Proc.new{|options, host|
  unless /^https?\:\/\//.match? host
    if options["encryption"] == "ssl"
      host = "https://#{host}"
    else
      host = "http://#{host}"
    end
  end

  host
})
```

### Default Values that Depend on another Option

Suppose you want to set the default value of the `port` option based on the encryption chosen by the user of the `Mailer` class. More precisely, you want to set the port to `465` if SSL is used and to `25` otherwise.

You can implement this feature by passing a proc (or lambda) as the default value of the `port` option. The proc (or lambda) receives the options as argument. Based on these options, you can return the desired default value:

```ruby
# ...
resolver.set_default("encryption", nil)
  .set_default("port", lambda{|options, _| options["encryption"] == "ssl" ? 465 :25})
```

> The argument of the callable must be type hinted as `options`. Otherwise, the callable itself is considered as the default value of the option.

> The proc (or lambda) is only executed if the `port` option isn't set by the user or overwritten in a sub-class.

A previously set default value can be accessed by adding a second argument to the proc (or lambda):

```ruby
resolver.set_defaults({
  encryption: nil,
  host: "example.org"
}).set_default("host", Proc.new{|options, previous_host_value|
  options["encryption"] == "ssl" ? "secure.example.org" : previous_host_value
})
```

As seen in the example, this feature is mostly useful if you want to reuse the default values set in parent classes in sub-classes.

### Options without Default Values

In some cases, it is useful to define an option without setting a default value. This is useful if you need to know whether or not the user _actually_ set an option or not. For example, if you set the default value for an option, it's not possible to know whether the user passed this value or if it simply comes from the default:

```ruby
class Mailer
  def initialize options
    resolver = OptionsResolver.new
    resolver.set_default("port", 25)

    @options = resolver.resolve options
  end

  def send_mail from, to
    # Is this the default value or did the caller of the class really
    # set the port to 25?

    if @options["port"] == 25
      # ...
    end
  end
end
```

You can use `set_defined()` to define an option without setting a default value. Then the option will only be included in the resolved options if it was actually passed to `resolve()`:

```ruby
class Mailer
  def initialize options
    resolver = OptionsResolver.new
    resolver.set_defined "port"

    @options = resolver.resolve options
  end

  def send_mail from = nil, to = nil
    if @options["port"]
      puts "Set!"
    else
      puts "Not set"
    end
  end
end

mailer_opts = {}
mailer = Mailer.new mailer_opts
mailer.send_mail
# => Not set!

mailer_opts = {port: 25}
mailer = Mailer.new mailer_opts
mailer.send_mail
# => Set!
```

You can also pass an array of option names if you want to define multiple options in one go:

```ruby
resolver.set_defined %w(port encryption)
```

The methods `is_defined?()` and `get_defined_options()` let you find out which options are defined:

```ruby
# ...
if resolver.is_defined? "host"
  # One of the following was called:
  # resolver.set_default "host", ...
  # resolver.set_required "host"
  # resolver.set_defined "host"
end

defined_options = resolver.get_defined_options
```

That's it! You now have all the tools and knowledge needed to easily process options in your code.

# Credits

Original documentation for PHP: [https://symfony.com/doc/3.4/components/options_resolver.html](https://symfony.com/doc/3.4/components/options_resolver.html)
