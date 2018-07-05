require "optionsresolver/exceptions/invalid_parameter"
require "optionsresolver/exceptions/undefined_options"
require "optionsresolver/exceptions/missing_options"
require "optionsresolver/exceptions/invalid_options"
require "optionsresolver/utils/hash_ext"

class OptionsResolver
  def initialize
    @defined_options = []
    @required_options = []
    @default_values = {}
    @allowed_types = {}
    @allowed_values = {}
    @normalizers = {}
    @previous_default_values = {}
  end

  def set_defined defined_keys
    if defined_keys.is_a?(Array)
      @defined_options.concat defined_keys
    else
      @defined_options.push defined_keys
    end

    self
  end

  def get_defined_options
    @defined_options
  end

  def is_defined? option_key
    @defined_options.include? option_key
  end

  def set_required required_keys
    if required_keys.is_a?(Array)
      @required_options.concat required_keys
      @defined_options.concat required_keys
    else
      @required_options.push required_keys
      @defined_options.push required_keys
    end

    self
  end

  def get_required_options
    @required_options
  end

  def is_required? option_key
    @required_options.include? option_key
  end

  def is_missing? option_key
    !@default_values.include? option_key
  end

  def get_missing_options
    @required_options.map do |required_key|
      next if @default_values.include?(required_key)
      required_key
    end.compact
  end

  def set_default option_key, default_value
    @previous_default_values[option_key] = @default_values[option_key] if
      @default_values.include? option_key

    @default_values[option_key] = default_value
    self.set_defined option_key

    self
  end

  def set_defaults option_default_values
    raise InvalidParameter unless option_default_values.is_a? Hash

    option_default_values.each do |opt_key, opt_value|
      opt_key = opt_key.to_s

      self.set_default(opt_key, opt_value).set_defined opt_key
    end

    self
  end

  def get_default_values option_key = nil
    return @default_values unless option_key

    @default_values[option_key]
  end

  def set_allowed_types option_key, option_value_types
    @allowed_types[option_key] = option_value_types

    self
  end

  def get_allowed_types option_key = nil
    return @allowed_types unless option_key

    @allowed_types[option_key]
  end

  def set_allowed_values option_key, option_allowed_value
    @allowed_values[option_key] = option_allowed_value

    self
  end

  def get_allowed_values option_key = nil
    return @allowed_values unless option_key

    @allowed_values
  end

  def set_normalizer option_key, normalizer_value
    @normalizers[option_key] = normalizer_value

    self
  end

  def resolve data_object
    raise InvalidParameter unless data_object.is_a? Hash

    # Unique @defined_options
    @defined_options.uniq!
    # Stringify hash keys
    data_object = data_object.stringify_keys
    # Check undefined options
    check_undefined_options data_object.keys
    # Set default values
    data_object = set_options_default data_object
    # Check missing required options
    check_missing_required_options data_object
    # Check invalid options type
    check_invalid_options_type data_object
    # Check invalid options value
    check_invalid_options_value data_object
    # Normalizer options value
    data_object = normalizer_options_value data_object

    data_object
  end

  private
  def check_undefined_options option_keys
    know_options_str = "\"#{@defined_options.join("\", \"")}\""

    option_keys.each do |opt_key|
      raise UndefinedOptions, "The option \"#{opt_key}\" does not exist. Know options are: #{know_options_str}" unless
        @defined_options.include? opt_key.to_s
    end
  end

  def set_options_default data_object
    @default_values.each do |option_key, default_value|
      next unless data_object[option_key].nil?

      previous_default_value = @previous_default_values[option_key]
      data_object[option_key] = default_value.is_a?(Proc) ? default_value.call(data_object, previous_default_value) : default_value
    end

    data_object
  end

  def check_missing_required_options data_object
    @required_options.each do |required_key|
      next if data_object[required_key.to_s]

      raise MissingOptions, "The required options \"#{required_key}\" is missing."
    end
  end

  def check_invalid_options_type data_object
    @allowed_types.each do |option_key, allowed_type|
      option_key = option_key.to_s
      option_value = data_object[option_key]

      case allowed_type.downcase
      when "int", "integer"
        throw_invalid_options_exception option_key, option_value, "int" unless option_value.is_a? Integer
      when "str", "string"
        throw_invalid_options_exception option_key, option_value, "str" unless option_value.is_a? String
      when "arr", "array"
        throw_invalid_options_exception option_key, option_value, "array" unless option_value.is_a? Array
      when "bool", "boolean"
        throw_invalid_options_exception option_key, option_value, "boolean" unless [true, false].include? option_value
      when "float"
        throw_invalid_options_exception option_key, option_value, "float" unless option_value.is_a? Float
      when "hash"
        throw_invalid_options_exception option_key, option_value, "hash" unless option_value.is_a? Hash
      when "sym", "symbol"
        throw_invalid_options_exception option_key, option_value, "symbol" unless option_value.is_a? Symbol
      when "range"
        throw_invalid_options_exception option_key, option_value, "range" unless option_value.is_a? Range
      when "regexp"
        throw_invalid_options_exception option_key, option_value, "regexp" unless option_value.is_a? Regexp
      when "proc"
        throw_invalid_options_exception option_key, option_value, "proc" unless option_value.is_a? Proc
      end
    end
  end

  def check_invalid_options_value data_object
    @allowed_values.each do |option_key, allowed_value|
      option_key = option_key.to_s
      option_value = data_object[option_key]
      is_valid_value = true
      accepted_value_msg = ""

      if allowed_value.is_a? Array
        is_valid_value = allowed_value.include? option_value
        accepted_value_msg = " Accepted values are \"#{allowed_value.join("\", \"")}\""
      elsif allowed_value.is_a? Proc
        is_valid_value = allowed_value.call option_value
      else
        is_valid_value = (option_value == allowed_value)
      end

      raise "The option \"#{option_key}\" with value \"#{option_value}\" is invalid.#{accepted_value_msg}" unless is_valid_value
    end
  end

  def normalizer_options_value data_object
    @normalizers.each do |option_key, normalizer_method|
      raise InvalidParameter "Normalizer for key \"#{option_key}\" has invalid method." unless normalizer_method.is_a? Proc

      option_value = data_object[option_key]
      data_object[option_key] = normalizer_method.call data_object, option_value
    end

    data_object
  end

  def throw_invalid_options_exception key, val, expected_type
    msg = "The option \"#{key}\" with \"#{val}\" is expected to be of type \"#{expected_type}\""
    raise InvalidOptions, msg
  end
end
