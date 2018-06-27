require "optionsresolver/exceptions/invalid_parameter"
require "optionsresolver/exceptions/undefined_options"

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

    check_undefined_options data_object.keys
    data_object = set_options_default data_object
  end

  private
  def check_undefined_options option_keys
    know_options_str = "\"#{@defined_options.join("\", \"")}\""

    option_keys.each do |opt_key|
      raise UndefinedOptions, "The option \"#{opt_key}\" does not exist. Know options are: #{know_options_str}" unless
        @defined_options.include? opt_key.to_s
    end
  end
end
