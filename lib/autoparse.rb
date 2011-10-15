# Copyright 2010 Google Inc
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'autoparse/instance'
require 'autoparse/version'
require 'addressable/uri'

module AutoParse
  def self.schemas
    @schemas ||= {}
  end

  def self.generate(schema_data, uri=nil)
    if schema_data["extends"]
      super_uri = uri + Addressable::URI.parse(schema_data["extends"])
      super_schema = self.schemas[super_uri]
      if super_schema == nil
        raise ArgumentError,
          "Could not find schema to extend: #{schema_data["extends"]} " +
          "Parent schema must be parsed before child schema."
      end
    else
      super_schema = Instance
    end
    schema = Class.new(super_schema) do
      @uri = Addressable::URI.parse(uri)
      @uri.normalize! if @uri != nil
      @schema_data = schema_data

      def self.additional_properties_schema
        # Override the superclass implementation so we're not always returning
        # the empty schema.
        return @additional_properties_schema
      end

      (@schema_data['properties'] || []).each do |(k, v)|
        property_key, property_schema = k, v
        property_name = INFLECTOR.underscore(property_key).gsub("-", "_")
        property_super_schema = super_schema.properties[property_key]
        if property_super_schema
          # TODO: Not sure if this should be a recursive merge or not...

          # TODO: Might need to raise an error if a schema is extended in
          # a way that violates the requirement that all child instances also
          # validate against the parent schema.
          property_schema = property_super_schema.data.merge(property_schema)
        end

        if schema_data.has_key?('id')
          property_schema_class = AutoParse.generate(property_schema)
        else
          # If the schema has no ID, it inherits the ID from the parent schema.
          property_schema_class = AutoParse.generate(property_schema, @uri)
        end

        self.properties[property_key] = property_schema_class
        self.keys[property_name] = property_key

        define_method(property_name) do
          __get__(property_name)
        end
        define_method(property_name + '=') do |value|
          __set__(property_name, value)
        end
      end

      if schema_data['additionalProperties'] == true ||
          schema_data['additionalProperties'] == nil
        # Schema-less unknown properties are allowed.
        @additional_properties_schema = EMPTY_SCHEMA
        define_method('method_missing') do |method, *params, &block|
          # We need to convert from Ruby calling style to JavaScript calling
          # style. If this fails, attempt to use JavaScript calling style
          # directly.

          # We can't modify the method in-place because this affects the call
          # to super.
          stripped_method = method.to_s
          assignment = false
          if stripped_method[-1..-1] == '='
            assignment = true
            stripped_method[-1..-1] = ''
          end
          key = INFLECTOR.camelize(stripped_method)
          key[0..0] = key[0..0].downcase
          if self[key] != nil
            value = self[key]
          elsif self[stripped_method] != nil
            key = stripped_method
            value = self[stripped_method]
          else
            # Method not found.
            super
          end
          # If additionalProperties is simply set to true, no parsing takes
          # place and all values are treated as 'any'.
          if assignment
            new_value = params[0]
            self[key] = new_value
          else
            value
          end
        end

      elsif schema_data['additionalProperties']
        # Unknown properties follow the supplied schema.
        ap_schema = AutoParse.generate(schema_data['additionalProperties'])
        @additional_properties_schema = ap_schema
        define_method('method_missing') do |method, *params, &block|
          # We need to convert from Ruby calling style to JavaScript calling
          # style. If this fails, attempt to use JavaScript calling style
          # directly.

          # We can't modify the method in-place because this affects the call
          # to super.
          stripped_method = method.to_s
          assignment = false
          if stripped_method[-1..-1] == '='
            assignment = true
            stripped_method[-1..-1] = ''
          end
          key = INFLECTOR.camelize(stripped_method)
          key[0..0] = key[0..0].downcase
          if self[key] != nil
            value = self[key]
          elsif self[stripped_method] != nil
            key = stripped_method
            value = self[stripped_method]
          else
            # Method not found.
            super
          end
          if assignment
            # In the case of assignment, it's very likely the developer is
            # passing in an unparsed Hash value. This value must be parsed.
            # Unfortunately, we may accidentally reparse something that's
            # already in a parsed state because Schema.new(Schema.new(data))
            # is completely valid. This will cause performance issues if
            # developers are careless, but since there's no good reason to
            # do assignment on parsed objects, hopefully this should not
            # cause problems often.
            new_value = params[0]
            self[key] = ap_schema.new(new_value)
          else
            ap_schema.new(value)
          end
        end
      else
        @additional_properties_schema = nil
      end

      if schema_data['dependencies']
        for dependency_key, dependency_data in schema_data['dependencies']
          self.property_dependencies[dependency_key] = dependency_data
        end
      end
    end

    # Register the new schema.
    self.schemas[schema.uri] = schema
    return schema
  end

  def self.import_string(value, schema_class)
    if value != nil
      format = schema_class.data['format']
      if format == 'byte'
        Base64.decode64(value)
      elsif format == 'date-time'
        Time.parse(value)
      elsif format == 'url'
        Addressable::URI.parse(value)
      elsif format =~ /^u?int(32|64)$/
        value.to_i
      else
        value
      end
    else
      nil
    end
  end

  def self.export_string(value, schema_class)
    format = schema_class.data['format']
    if format == 'byte'
      Base64.encode64(value)
    elsif format == 'date-time'
      if value.respond_to?(:to_str)
        value = Time.parse(value.to_str)
      elsif !value.respond_to?(:xmlschema)
        raise TypeError,
          "Could not obtain RFC 3339 timestamp from #{value.class}."
      end
      value.xmlschema
    elsif format == 'url'
      # This effectively does limited URI validation.
      Addressable::URI.parse(value).to_str
    elsif format =~ /^u?int(32|64)$/
      value.to_s
    elsif value.respond_to?(:to_str)
      value.to_str
    elsif value.kind_of?(Symbol)
      value.to_s
    else
      raise TypeError,
        "Expected String or Symbol, got #{value.class}."
    end
  end

  def self.import_boolean(value, schema_class)
    case value.to_s.downcase
    when 'true', 'yes', 'y', 'on', '1'
      true
    when 'false', 'no', 'n', 'off', '0'
      false
    when 'nil', 'null', 'undefined'
      nil
    else
      raise TypeError,
        "Expected boolean, got #{value.class}."
    end
  end

  def self.export_boolean(value, schema_class)
    case value.to_s.downcase
    when 'true', 'yes', 'y', 'on', '1'
      true
    when 'false', 'no', 'n', 'off', '0'
      false
    when 'nil', 'null', 'undefined'
      nil
    else
      raise TypeError, "Expected boolean, got #{value.class}."
    end
  end

  def self.import_number(value, schema_class)
    if value == nil
      value
    else
      Float(value)
    end
  end

  def self.export_number(value, schema_class)
    if value == nil
      value
    else
      Float(value)
    end
  end

  def self.import_integer(value, schema_class)
    if value == nil
      value
    else
      Integer(value)
    end
  end

  def self.export_integer(value, schema_class)
    if value == nil
      value
    else
      Integer(value)
    end
  end

  def self.import_array(value, schema_class)
    array = (if value != nil && !value.respond_to?(:to_ary)
      raise TypeError,
        "Expected Array, got #{value.class}."
    else
      (value || []).to_ary
    end)
    items_data = schema_class.data['items']
    if items_data && items_data['$ref']
      if schema_class && schema_class.uri
        items_uri =
          schema_class.uri + Addressable::URI.parse(items_data['$ref'])
      else
        items_uri = Addressable::URI.parse(items_data['$ref'])
      end
      items_schema = AutoParse.schemas[items_uri]
      if items_schema
        array.map! do |item|
          items_schema.new(item)
        end
      else
        raise ArgumentError,
          "Could not find schema: #{items_uri}."
      end
    end
    array
  end

  def self.export_array(value, schema_class)
    # FIXME: Each item in the Array needs to be exported as well.
    if value == nil
      value
    elsif value.respond_to?(:to_ary)
      value.to_ary
    else
      raise TypeError, "Expected Array, got #{value.class}."
    end
  end

  def self.import_object(value, schema_class)
    value ? schema_class.new(value) : nil
  end

  def self.export_object(value, schema_class)
    # FIXME: Every field must be exported as well.
    if value.nil?
      nil
    elsif value.respond_to?(:to_hash)
      value.to_hash
    elsif value.respond_to?(:to_json)
      ::JSON.parse(value.to_json)
    else
      raise TypeError, "Expected Hash, got #{value.class}."
    end
  end

  def self.import_union(value, schema_class)
    import_type = match_type(
      value, schema_class.data['type'], schema_class.uri
    )
    case import_type
    when 'string'
      AutoParse.import_string(value, schema_class)
    when 'boolean'
      AutoParse.import_boolean(value, schema_class)
    when 'integer'
      AutoParse.import_integer(value, schema_class)
    when 'number'
      AutoParse.import_number(value, schema_class)
    when 'array'
      AutoParse.import_array(value, schema_class)
    when 'object'
      AutoParse.import_object(value, schema_class)
    when 'null'
      nil
    when Class
      AutoParse.import_object(value, import_type)
    else
      AutoParse.import_any(value, schema_class)
    end
  end

  def self.export_union(value, schema_class)
    export_type = match_type(
      value, schema_class.data['type'], schema_class.uri
    )
    case export_type
    when 'string'
      AutoParse.export_string(value, schema_class)
    when 'boolean'
      AutoParse.export_boolean(value, schema_class)
    when 'integer'
      AutoParse.export_integer(value, schema_class)
    when 'number'
      AutoParse.export_number(value, schema_class)
    when 'array'
      AutoParse.export_array(value, schema_class)
    when 'object'
      AutoParse.export_object(value, schema_class)
    when 'null'
      nil
    when Class
      AutoParse.export_object(value, export_type)
    else
      AutoParse.export_any(value, schema_class)
    end
  end

  def self.import_any(value, schema_class)
    value
  end

  def self.export_any(value, schema_class)
    value
  end

  ##
  # Given a value and a union of types, selects the type which is the best
  # match for the given value. More than one type may match the value, in which
  # case, the first type in the union will be returned.
  def self.match_type(value, union, base_uri=nil)
    possible_types = [union].flatten.compact
    # Strict pass
    for type in possible_types
      # We import as the first type in the list that validates.
      case type
      when 'string'
        return 'string' if value.kind_of?(String)
      when 'boolean'
        return 'boolean' if value == true or value == false
      when 'integer'
        return 'integer' if value.kind_of?(Integer)
      when 'number'
        return 'number' if value.kind_of?(Numeric)
      when 'array'
        return 'array' if value.kind_of?(Array)
      when 'object'
        return 'object' if value.kind_of?(Hash) || value.kind_of?(Instance)
      when 'null'
        return 'null' if value.nil?
      when Hash
        # Schema embedded directly.
        unless base_uri
          schema_class = AutoParse.generate(type)
        else
          schema_class = AutoParse.generate(type, base_uri)
        end
        if type['$ref']
          schema_class = schema_class.dereference
        end
        return schema_class if schema_class.new(value).valid?
      end
    end
    # Lenient pass
    for type in possible_types
      # We import as the first type in the list that validates.
      case type
      when 'string'
        return 'string' if value.respond_to?(:to_str) || value.kind_of?(Symbol)
      when 'boolean'
        if ['true', 'yes', 'y', 'on', '1',
            'false', 'no', 'n', 'off', '0'].include?(value.to_s.downcase)
          return 'boolean'
        end
      when 'integer'
        return 'integer' if value.to_i != 0 || value == "0"
      when 'number'
        return 'number' if value.to_f != 0.0 || value == "0" || value == "0.0"
      when 'array'
        return 'array' if value.respond_to?(:to_ary)
      when 'object'
        if value.respond_to?(:to_hash) || value.respond_to?(:to_json)
          return 'object'
        end
      when 'any'
        return 'any'
      end
    end
    return nil
  end
end
