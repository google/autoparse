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
          property_schema = property_super_schema.merge(property_schema)
        end
        self.properties[property_key] = property_schema
        if property_schema['$ref']
          schema_uri =
            self.uri + Addressable::URI.parse(property_schema['$ref'])
          schema = AutoParse.schemas[schema_uri]
          if schema == nil
            raise ArgumentError,
              "Could not find schema: #{property_schema['$ref']} " +
              "Referenced schema must be parsed first."
          end
          property_schema = schema.data
        end
        case property_schema['type']
        when 'string'
          define_string_property(
            property_name, property_key, property_schema
          )
        when 'boolean'
          define_boolean_property(
            property_name, property_key, property_schema
          )
        when 'number'
          define_number_property(
            property_name, property_key, property_schema
          )
        when 'integer'
          define_integer_property(
            property_name, property_key, property_schema
          )
        when 'array'
          define_array_property(
            property_name, property_key, property_schema
          )
        when 'object'
          define_object_property(
            property_name, property_key, property_schema
          )
        else
          # Either type 'any' or we don't know what this is,
          # default to anything goes.
          define_any_property(
            property_name, property_key, property_schema
          )
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
        ap_schema = Schema.generate(schema_data['additionalProperties'])
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
          if dependency_data.kind_of?(Hash)
            dependency_data = AutoParse.generate(dependency_data)
          end
          self.property_dependencies[dependency_key] = dependency_data
        end
      end
    end

    # Register the new schema.
    self.schemas[schema.uri] = schema
    return schema
  end
end
