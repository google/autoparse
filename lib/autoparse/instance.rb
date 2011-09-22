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


require 'json'
require 'time'
require 'autoparse/inflection'
require 'addressable/uri'

module AutoParse
  class Instance
    def self.uri
      return @uri ||= nil
    end

    def self.properties
      return @properties ||= {}
    end

    def self.additional_properties_schema
      return EMPTY_SCHEMA
    end

    def self.property_dependencies
      return @property_dependencies ||= {}
    end

    def self.data
      return @schema_data
    end

    def self.description
      return @schema_data['description']
    end

    def self.validate_string_property(property_value, schema_data)
      property_value = property_value.to_str rescue property_value
      if !property_value.kind_of?(String)
        return false
      else
        # TODO: implement more than type-checking
        return true
      end
    end

    def self.define_string_property(property_name, key, schema_data)
      define_method(property_name) do
        value = self[key] || schema_data['default']
        if value != nil
          if schema_data['format'] == 'byte'
            Base64.decode64(value)
          elsif schema_data['format'] == 'date-time'
            Time.parse(value)
          elsif schema_data['format'] == 'url'
            Addressable::URI.parse(value)
          elsif schema_data['format'] =~ /^u?int(32|64)$/
            value.to_i
          else
            value
          end
        else
          nil
        end
      end
      define_method(property_name + '=') do |value|
        if schema_data['format'] == 'byte'
          self[key] = Base64.encode64(value)
        elsif schema_data['format'] == 'date-time'
          if value.respond_to?(:to_str)
            value = Time.parse(value.to_str)
          elsif !value.respond_to?(:xmlschema)
            raise TypeError,
              "Could not obtain RFC 3339 timestamp from #{value.class}."
          end
          self[key] = value.xmlschema
        elsif schema_data['format'] == 'url'
          # This effectively does limited URI validation.
          self[key] = Addressable::URI.parse(value).to_str
        elsif schema_data['format'] =~ /^u?int(32|64)$/
          self[key] = value.to_s
        elsif value.respond_to?(:to_str)
          self[key] = value.to_str
        elsif value.kind_of?(Symbol)
          self[key] = value.to_s
        else
          raise TypeError,
            "Expected String or Symbol, got #{value.class}."
        end
      end
    end

    def self.define_boolean_property(property_name, key, schema_data)
      define_method(property_name) do
        value = self[key] || schema_data['default']
        case value.to_s.downcase
        when 'true', 'yes', 'y', 'on', '1'
          true
        when 'false', 'no', 'n', 'off', '0'
          false
        when 'nil', 'null'
          nil
        else
          raise TypeError,
            "Expected boolean, got #{value.class}."
        end
      end
      define_method(property_name + '=') do |value|
        case value.to_s.downcase
        when 'true', 'yes', 'y', 'on', '1'
          self[key] = true
        when 'false', 'no', 'n', 'off', '0'
          self[key] = false
        when 'nil', 'null'
          self[key] = nil
        else
          raise TypeError, "Expected boolean, got #{value.class}."
        end
      end
    end

    def self.validate_number_property(property_value, schema_data)
      return false if !property_value.kind_of?(Numeric)
      # TODO: implement more than type-checking
      return true
    end

    def self.define_number_property(property_name, key, schema_data)
      define_method(property_name) do
        Float(self[key] || schema_data['default'])
      end
      define_method(property_name + '=') do |value|
        if value == nil
          self[key] = value
        else
          self[key] = Float(value)
        end
      end
    end

    def self.validate_integer_property(property_value, schema_data)
      return false if !property_value.kind_of?(Integer)
      if schema_data['minimum'] && schema_data['exclusiveMinimum']
        return false if property_value <= schema_data['minimum']
      elsif schema_data['minimum']
        return false if property_value < schema_data['minimum']
      end
      if schema_data['maximum'] && schema_data['exclusiveMaximum']
        return false if property_value >= schema_data['maximum']
      elsif schema_data['maximum']
        return false if property_value > schema_data['maximum']
      end
      return true
    end

    def self.define_integer_property(property_name, key, schema_data)
      define_method(property_name) do
        Integer(self[key] || schema_data['default'])
      end
      define_method(property_name + '=') do |value|
        if value == nil
          self[key] = value
        else
          self[key] = Integer(value)
        end
      end
    end

    def self.validate_array_property(property_value, schema_data)
      if property_value.respond_to?(:to_ary)
        property_value = property_value.to_ary
      else
        return false
      end
      property_value.each do |item_value|
        unless self.validate_property_value(item_value, schema_data['items'])
          return false
        end
      end
      return true
    end

    def self.define_array_property(property_name, key, schema_data)
      define_method(property_name) do
        # The default value of an empty Array obviates a mutator method.
        value = self[key] || []
        array = if value != nil && !value.respond_to?(:to_ary)
          raise TypeError,
            "Expected Array, got #{value.class}."
        else
          value.to_ary
        end
        if schema_data['items'] && schema_data['items']['$ref']
          schema_name = schema_data['items']['$ref']
          # FIXME: Vestigial bits need to be replaced with a more viable
          # lookup system.
          if AutoParse.schemas[schema_name]
            schema_class = AutoParse.schemas[schema_name]
            array.map! do |item|
              schema_class.new(item)
            end
          else
            raise ArgumentError,
              "Could not find schema: #{schema_uri}."
          end
        end
        array
      end
    end

    def self.validate_object_property(property_value, schema_data, schema=nil)
      if property_value.kind_of?(Instance)
        return property_value.valid?
      elsif schema != nil && schema.kind_of?(Class)
        return schema.new(property_value).valid?
      else
        # This is highly ineffecient, but hard to avoid given the schema is
        # anonymous.
        schema = AutoParse.generate(schema_data)
        return schema.new(property_value).valid?
      end
    end

    def self.define_object_property(property_name, key, schema_data)
      # TODO finish this up...
      if schema_data['$ref']
        schema_uri = self.uri + Addressable::URI.parse(schema_data['$ref'])
        schema = AutoParse.schemas[schema_uri]
        if schema == nil
          raise ArgumentError,
            "Could not find schema: #{schema_data['$ref']} " +
            "Referenced schema must be parsed first."
        end
      else
        # Anonymous schema
        schema = AutoParse.generate(schema_data)
      end
      define_method(property_name) do
        schema.new(self[key] || schema_data['default'])
      end
    end

    def self.define_any_property(property_name, key, schema_data)
      define_method(property_name) do
        self[key] || schema_data['default']
      end
      define_method(property_name + '=') do |value|
        self[key] = value
      end
    end

    ##
    # @api private
    def self.validate_property_value(property_value, schema_data)
      if property_value == nil && schema_data['required'] == true
        return false
      elsif property_value == nil
        # Value was omitted, but not required. Still valid.
        return true
      end

      # Verify property values
      if schema_data['$ref']
        schema_uri = self.uri + Addressable::URI.parse(schema_data['$ref'])
        schema = AutoParse.schemas[schema_uri]
        if schema == nil
          raise ArgumentError,
            "Could not find schema: #{schema_data['$ref']} " +
            "Referenced schema must be parsed first."
        end
        schema_data = schema.data
      end
      case schema_data['type']
      when 'string'
        return false unless self.validate_string_property(
          property_value, schema_data
        )
      when 'boolean'
        return false unless self.validate_boolean_property(
          property_value, schema_data
        )
      when 'number'
        return false unless self.validate_number_property(
          property_value, schema_data
        )
      when 'integer'
        return false unless self.validate_integer_property(
          property_value, schema_data
        )
      when 'array'
        return false unless self.validate_array_property(
          property_value, schema_data
        )
      when 'object'
        return false unless self.validate_object_property(
          property_value, schema_data
        )
      else
        # Either type 'any' or we don't know what this is,
        # default to anything goes. Validation of an 'any' property always
        # succeeds.
      end
      return true
    end

    def initialize(data)
      if self.class.data &&
          self.class.data['type'] &&
          self.class.data['type'] != 'object'
        raise TypeError,
          "Only schemas of type 'object' are instantiable."
      end
      if data.respond_to?(:to_hash)
        data = data.to_hash
      elsif data.respond_to?(:to_json)
        data = JSON.parse(data.to_json)
      else
        raise TypeError,
          'Unable to parse. ' +
          'Expected data to respond to either :to_hash or :to_json.'
      end
      @data = data
    end

    def [](key)
      return @data[key]
    end

    def []=(key, value)
      return @data[key] = value
    end

    ##
    # Validates the parsed data against the schema.
    def valid?
      unvalidated_fields = @data.keys.dup
      for property_key, property_schema in self.class.properties
        property_value = self[property_key]
        if !self.class.validate_property_value(property_value, property_schema)
          return false
        end
        if property_value == nil && property_schema['required'] != true
          # Value was omitted, but not required. Still valid. Skip dependency
          # checks.
          next
        end

        # Verify property dependencies
        property_dependencies = self.class.property_dependencies[property_key]
        case property_dependencies
        when String, Array
          property_dependencies = [property_dependencies].flatten
          for dependency_key in property_dependencies
            dependency_value = self[dependency_key]
            return false if dependency_value == nil
          end
        when Class
          if property_dependencies.ancestors.include?(Instance)
            dependency_instance = property_dependencies.new(property_value)
            return false unless dependency_instance.valid?
          else
            raise TypeError,
              "Expected schema Class, got #{property_dependencies.class}."
          end
        end
      end
      if self.class.additional_properties_schema == nil
        # No additional properties allowed
        return false unless unvalidated_fields.empty?
      elsif self.class.additional_properties_schema != EMPTY_SCHEMA
        # Validate all remaining fields against this schema

        # Make sure tests don't pass prematurely
        return false
      end
      if self.class.superclass && self.class.superclass != Instance &&
          self.class.ancestors.first != Instance
        # The spec actually only defined the 'extends' semantics as children
        # must also validate aainst the parent.
        return false unless self.class.superclass.new(@data).valid?
      end
      return true
    end

    def to_hash
      return @data
    end

    def to_json
      return JSON.generate(self.to_hash)
    end

    ##
    # Returns a <code>String</code> representation of the schema instance.
    #
    # @return [String] The instance's state, as a <code>String</code>.
    def inspect
      if self.class.respond_to?(:description)
        sprintf(
          "#<%s:%#0x DESC:'%s'>",
          self.class.to_s, self.object_id, self.class.description
        )
      else
        sprintf("#<%s:%#0x>", self.class.to_s, self.object_id)
      end
    end
  end

  ##
  # The empty schema accepts all JSON.
  EMPTY_SCHEMA = Instance
end
