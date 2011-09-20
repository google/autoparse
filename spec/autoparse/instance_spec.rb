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


spec_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'spec_helper'

require 'json'
require 'autoparse'
require 'addressable/uri'

describe AutoParse::Instance, 'with an empty schema' do
  before do
    @parser = AutoParse::EMPTY_SCHEMA
  end

  it 'should accept all inputs' do
    instance = @parser.new({
      "this" => "doesn't",
      "really" => ["matter", "at", "all"],
      "!" => 1.2345
    })
    instance.should be_valid
  end

  it 'should expose values via index methods' do
    instance = @parser.new({
      "this" => "doesn't",
      "really" => ["matter", "at", "all"],
      "!" => 1.2345
    })
    instance["this"].should == "doesn't"
    instance["really"].should == ["matter", "at", "all"]
    instance["!"].should == 1.2345
  end

  it 'should be coerceable to a Hash value' do
    instance = @parser.new({
      "this" => "doesn't",
      "really" => ["matter", "at", "all"],
      "!" => 1.2345
    })
    instance.to_hash.should == {
      "this" => "doesn't",
      "really" => ["matter", "at", "all"],
      "!" => 1.2345
    }
  end

  it 'should convert to a JSON string' do
    instance = @parser.new({"be" => "brief"})
    instance.to_json.should == '{"be":"brief"}'
  end
end

describe AutoParse::Instance, 'with the geo schema' do
  before do
    @uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/geo.json'))
    )
    @schema_data = JSON.parse(File.open(@uri.path, 'r') { |f| f.read })
    @parser = AutoParse.generate(@schema_data, @uri)
  end

  it 'should accept a valid geographic coordinate input' do
    instance = @parser.new({
      "latitude" => 37.422,
      "longitude" => -122.084
    })
    instance.should be_valid
  end

  it 'should not accept an invalid geographic coordinate input' do
    instance = @parser.new({
      "latitude" => "not",
      "longitude" => "valid"
    })
    instance.should_not be_valid
  end

  it 'should accept extra fields' do
    instance = @parser.new({
      "latitude" => 37.422,
      "longitude" => -122.084,
      "extra" => "bonus!"
    })
    instance.should be_valid
  end

  it 'should expose values via generated accessors' do
    instance = @parser.new({
      "latitude" => 37.422,
      "longitude" => -122.084
    })
    instance.latitude.should == 37.422
    instance.longitude.should == -122.084
  end

  it 'should be coerceable to a Hash value' do
    instance = @parser.new({
      "latitude" => 37.422,
      "longitude" => -122.084
    })
    instance.to_hash.should == {
      "latitude" => 37.422,
      "longitude" => -122.084
    }
  end

  it 'should convert to a JSON string' do
    instance = @parser.new({
      "latitude" => 37.422,
      "longitude" => -122.084
    })
    instance.to_json.should == '{"latitude":37.422,"longitude":-122.084}'
  end
end


describe AutoParse::Instance, 'with the address schema' do
  before do
    @uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/address.json'))
    )
    @schema_data = JSON.parse(File.open(@uri.path, 'r') { |f| f.read })
    @parser = AutoParse.generate(@schema_data, @uri)
  end

  it 'should accept a valid address input' do
    instance = @parser.new({
      "post-office-box" => "PO Box 3.14159",
      "street-address" => "1600 Amphitheatre Parkway",
      "locality" => "Mountain View",
      "region" => "CA",
      "postal-code" => "94043",
      "country-name" => "United States"
    })
    instance.should be_valid
  end

  it 'should accept extra fields' do
    instance = @parser.new({
      "post-office-box" => "PO Box 3.14159",
      "street-address" => "1600 Amphitheatre Parkway",
      "locality" => "Mountain View",
      "region" => "CA",
      "postal-code" => "94043",
      "country-name" => "United States",
      "extra" => "bonus!"
    })
    instance.should be_valid
  end

  it 'should accept a minimally valid address input' do
    instance = @parser.new({
      "locality" => "Mountain View",
      "region" => "CA",
      "country-name" => "United States"
    })
    instance.should be_valid
  end

  it 'should not accept an address with unmet dependencies' do
    instance = @parser.new({
      "post-office-box" => "PO Box 3.14159",
      "extended-address" => "Apt 2.71828",
      "locality" => "Mountain View",
      "region" => "CA",
      "country-name" => "United States"
    })
    instance.should_not be_valid
  end

  it 'should expose values via generated accessors' do
    instance = @parser.new({
      "post-office-box" => "PO Box 3.14159",
      "street-address" => "1600 Amphitheatre Parkway",
      "locality" => "Mountain View",
      "region" => "CA",
      "postal-code" => "94043",
      "country-name" => "United States"
    })
    instance.post_office_box.should == "PO Box 3.14159"
    instance.street_address.should == "1600 Amphitheatre Parkway"
    instance.locality.should == "Mountain View"
    instance.region.should == "CA"
    instance.postal_code.should == "94043"
    instance.country_name.should == "United States"
  end

  it 'should be coerceable to a Hash value' do
    instance = @parser.new({
      "post-office-box" => "PO Box 3.14159",
      "street-address" => "1600 Amphitheatre Parkway",
      "locality" => "Mountain View",
      "region" => "CA",
      "postal-code" => "94043",
      "country-name" => "United States"
    })
    instance.to_hash.should == {
      "post-office-box" => "PO Box 3.14159",
      "street-address" => "1600 Amphitheatre Parkway",
      "locality" => "Mountain View",
      "region" => "CA",
      "postal-code" => "94043",
      "country-name" => "United States"
    }
  end
end

describe AutoParse::Instance, 'with the person schema' do
  before do
    @uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/person.json'))
    )
    @schema_data = JSON.parse(File.open(@uri.path, 'r') { |f| f.read })
    @parser = AutoParse.generate(@schema_data, @uri)
  end

  it 'should accept a valid person input' do
    instance = @parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.should be_valid
  end

  it 'should accept extra fields' do
    instance = @parser.new({
      "name" => "Bob Aman",
      "age" => 29,
      "extra" => "bonus!"
    })
    instance.should be_valid
  end

  it 'should validate a person whose age is equal to the maximum' do
    instance = @parser.new({
      "name" => "Aged Outlier",
      "age" => 125
    })
    instance.should be_valid
  end

  it 'should validate a young person' do
    instance = @parser.new({
      "name" => "Joe Teenager",
      "age" => 15
    })
    instance.should be_valid
  end

  it 'should not accept an invalid person input' do
    instance = @parser.new({
      "name" => "Methuselah",
      "age" => 969
    })
    instance.should_not be_valid
  end

  it 'should not accept ages which are not integers' do
    instance = @parser.new({
      "name" => "Bob Aman",
      "age" => 29.7
    })
    instance.should_not be_valid
  end

  it 'should expose values via generated accessors' do
    instance = @parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.name.should == "Bob Aman"
    instance.age.should == 29
  end

  it 'should be coerceable to a Hash value' do
    instance = @parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.to_hash.should == {
      "name" => "Bob Aman",
      "age" => 29
    }
  end

  it 'should convert to a JSON string' do
    instance = @parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.to_json.should == '{"name":"Bob Aman","age":29}'
  end
end

describe AutoParse::Instance, 'with the adult schema' do
  before do
    @person_uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/person.json'))
    )
    @person_schema_data =
      JSON.parse(File.open(@person_uri.path, 'r') { |f| f.read })
    @person_parser = AutoParse.generate(@person_schema_data, @person_uri)
    @adult_uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/adult.json'))
    )
    @adult_schema_data =
      JSON.parse(File.open(@adult_uri.path, 'r') { |f| f.read })
    @adult_parser = AutoParse.generate(@adult_schema_data, @adult_uri)
  end

  it 'should accept a valid person input' do
    instance = @adult_parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.should be_valid
  end

  it 'should accept extra fields' do
    instance = @adult_parser.new({
      "name" => "Bob Aman",
      "age" => 29,
      "extra" => "bonus!"
    })
    instance.should be_valid
  end

  it 'should validate a person whose age is equal to the maximum' do
    instance = @adult_parser.new({
      "name" => "Aged Outlier",
      "age" => 125
    })
    instance.should be_valid
  end

  it 'should not validate a young person' do
    instance = @adult_parser.new({
      "name" => "Joe Teenager",
      "age" => 15
    })
    instance.should_not be_valid
  end

  it 'should not accept an invalid person input' do
    instance = @adult_parser.new({
      "name" => "Methuselah",
      "age" => 969
    })
    instance.should_not be_valid
  end

  it 'should not accept ages which are not integers' do
    instance = @adult_parser.new({
      "name" => "Bob Aman",
      "age" => 29.7
    })
    instance.should_not be_valid
  end

  it 'should expose values via generated accessors' do
    instance = @adult_parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.name.should == "Bob Aman"
    instance.age.should == 29
  end

  it 'should be coerceable to a Hash value' do
    instance = @adult_parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.to_hash.should == {
      "name" => "Bob Aman",
      "age" => 29
    }
  end

  it 'should convert to a JSON string' do
    instance = @adult_parser.new({
      "name" => "Bob Aman",
      "age" => 29
    })
    instance.to_json.should == '{"name":"Bob Aman","age":29}'
  end
end

describe AutoParse::Instance, 'with the card schema' do
  before do
    @address_uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/address.json'))
    )
    @address_schema_data =
      JSON.parse(File.open(@address_uri.path, 'r') { |f| f.read })
    @address_parser = AutoParse.generate(@address_schema_data, @address_uri)

    @geo_uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/geo.json'))
    )
    @geo_schema_data =
      JSON.parse(File.open(@geo_uri.path, 'r') { |f| f.read })
    @geo_parser = AutoParse.generate(@geo_schema_data, @geo_uri)

    @card_uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/card.json'))
    )
    @card_schema_data =
      JSON.parse(File.open(@card_uri.path, 'r') { |f| f.read })
    @card_parser = AutoParse.generate(@card_schema_data, @card_uri)
  end

  it 'should accept a valid card input' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman"
    })
    instance.should be_valid
  end

  it 'should accept extra fields' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "extra" => "bonus!"
    })
    instance.should be_valid
  end

  it 'should accept a more complete card input' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "additionalName" => ["Danger"],
      "nickname" => "Bob",
      "url" => "https://plus.google.com/116452824309856782163",
      "email" => {
        "type" => "work",
        "value" => "bobaman@google.com"
      },
      "tel" => {
        "type" => "fake",
        "value" => "867-5309"
      },
      "tz" => "+03:00",
      "logo" =>
        "https://secure.gravatar.com/avatar/56ee28134dd0776825445e3551979b14",
      "org" => {
        "organizationName" => "Google, Inc.",
        "organizationUnit" => "Developer Relations"
      }
    })
    instance.should be_valid
  end

  it 'should accept a card input with an externally referenced schema' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "adr" => {
        "locality" => "Lavington",
        "region" => "Nairobi",
        "country-name" => "Kenya"
      },
      "geo" => {
        "latitude" => -1.290034,
        "longitude" => 36.771584
      }
    })
    instance.adr.should be_valid
    instance.geo.should be_valid
    instance.should be_valid
  end

  it 'should not validate a card input with invalid array values' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "additionalName" => [3.14159]
    })
    instance.should_not be_valid
  end

  it 'should not validate a card input when external schema is invalid' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "adr" => {
        "extended-address" => "Apt 2.71828",
        "locality" => "Lavington",
        "region" => "Nairobi",
        "country-name" => "Kenya"
      },
      "geo" => {
        "latitude" => -1.290034,
        "longitude" => 36.771584
      }
    })
    instance.adr.should_not be_valid
    instance.should_not be_valid
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "adr" => {
        "locality" => "Lavington",
        "region" => "Nairobi",
        "country-name" => "Kenya"
      },
      "geo" => {
        "latitude" => "not",
        "longitude" => "valid"
      }
    })
    instance.geo.should_not be_valid
    instance.should_not be_valid
  end

  it 'should expose values via generated accessors' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "additionalName" => ["Danger"],
      "nickname" => "Bob",
      "url" => "https://plus.google.com/116452824309856782163",
      "email" => {
        "type" => "work",
        "value" => "bobaman@google.com"
      },
      "tel" => {
        "type" => "fake",
        "value" => "867-5309"
      },
      "tz" => "+03:00",
      "logo" =>
        "https://secure.gravatar.com/avatar/56ee28134dd0776825445e3551979b14",
      "org" => {
        "organizationName" => "Google, Inc.",
        "organizationUnit" => "Developer Relations"
      }
    })
    instance.given_name.should == "Robert"
    instance.family_name.should == "Aman"
    instance.additional_name.should == ["Danger"]
    instance.nickname.should == "Bob"
    instance.url.should be_kind_of(Addressable::URI)
    instance.url.should === "https://plus.google.com/116452824309856782163"
    instance.email.type.should == "work"
    instance.email.value.should == "bobaman@google.com"
    instance.tel.type.should == "fake"
    instance.tel.value.should == "867-5309"
    instance.tz.should == "+03:00"
    instance.logo.should ==
      "https://secure.gravatar.com/avatar/56ee28134dd0776825445e3551979b14"
    instance.org.organization_name.should == "Google, Inc."
    instance.org.organization_unit.should == "Developer Relations"
  end

  it 'should be coerceable to a Hash value' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman",
      "additionalName" => ["Danger"],
      "nickname" => "Bob",
      "url" => "https://plus.google.com/116452824309856782163",
      "email" => {
        "type" => "work",
        "value" => "bobaman@google.com"
      },
      "tel" => {
        "type" => "fake",
        "value" => "867-5309"
      },
      "tz" => "+03:00",
      "logo" =>
        "https://secure.gravatar.com/avatar/56ee28134dd0776825445e3551979b14",
      "org" => {
        "organizationName" => "Google, Inc.",
        "organizationUnit" => "Developer Relations"
      }
    })
    instance.to_hash.should == {
      "givenName" => "Robert",
      "familyName" => "Aman",
      "additionalName" => ["Danger"],
      "nickname" => "Bob",
      "url" => "https://plus.google.com/116452824309856782163",
      "email" => {
        "type" => "work",
        "value" => "bobaman@google.com"
      },
      "tel" => {
        "type" => "fake",
        "value" => "867-5309"
      },
      "tz" => "+03:00",
      "logo" =>
        "https://secure.gravatar.com/avatar/56ee28134dd0776825445e3551979b14",
      "org" => {
        "organizationName" => "Google, Inc.",
        "organizationUnit" => "Developer Relations"
      }
    }
  end

  it 'should convert to a JSON string' do
    instance = @card_parser.new({
      "givenName" => "Robert",
      "familyName" => "Aman"
    })
    instance.to_json.should == '{"givenName":"Robert","familyName":"Aman"}'
  end
end

describe AutoParse::Instance, 'with the calendar schema' do
  before do
    @geo_uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/geo.json'))
    )
    @geo_schema_data =
      JSON.parse(File.open(@geo_uri.path, 'r') { |f| f.read })
    @geo_parser = AutoParse.generate(@geo_schema_data, @geo_uri)

    @calendar_uri = Addressable::URI.new(
      :scheme => 'file',
      :host => '',
      :path => File.expand_path(File.join(spec_dir, './data/calendar.json'))
    )
    @calendar_schema_data =
      JSON.parse(File.open(@calendar_uri.path, 'r') { |f| f.read })
    @calendar_parser = AutoParse.generate(@calendar_schema_data, @calendar_uri)
  end

  it 'should accept a valid calendar input' do
    instance = @calendar_parser.new({
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day",
      "location" => "Googleplex",
      "url" => "http://www.piday.org/",
      "rrule" => "FREQ=YEARLY"
    })
    instance.should be_valid
  end

  it 'should accept extra fields' do
    instance = @calendar_parser.new({
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day",
      "location" => "Googleplex",
      "url" => "http://www.piday.org/",
      "rrule" => "FREQ=YEARLY",
      "extra" => "bonus!"
    })
    instance.should be_valid
  end

  it 'should accept a calendar input with an externally referenced schema' do
    instance = @calendar_parser.new({
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day",
      "location" => "Googleplex",
      "url" => "http://www.piday.org/",
      "rrule" => "FREQ=YEARLY",
      "geo" => {
        "latitude" => 37.422,
        "longitude" => -122.084
      }
    })
    instance.geo.should be_valid
    instance.should be_valid
  end

  it 'should not validate a calendar input when external schema is invalid' do
    instance = @calendar_parser.new({
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day",
      "location" => "Googleplex",
      "url" => "http://www.piday.org/",
      "rrule" => "FREQ=YEARLY",
      "geo" => {
        "latitude" => "not",
        "longitude" => "valid"
      }
    })
    instance.geo.should_not be_valid
    instance.should_not be_valid
  end

  it 'should expose values via generated accessors' do
    instance = @calendar_parser.new({
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day",
      "location" => "Googleplex",
      "url" => "http://www.piday.org/",
      "rrule" => "FREQ=YEARLY",
      "geo" => {
        "latitude" => 37.422,
        "longitude" => -122.084
      }
    })
    instance.dtstart.should == Time.utc(1592, 3, 14)
    instance.dtend.should == Time.utc(1592, 3, 14, 23, 59, 59)
    instance.summary.should == "Pi Day"
    instance.location.should == "Googleplex"
    instance.url.should == Addressable::URI.parse("http://www.piday.org/")
    instance.rrule.should == "FREQ=YEARLY"
    instance.geo.latitude.should == 37.422
    instance.geo.longitude.should == -122.084
  end

  it 'should be coerceable to a Hash value' do
    instance = @calendar_parser.new({
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day",
      "location" => "Googleplex",
      "url" => "http://www.piday.org/",
      "rrule" => "FREQ=YEARLY",
      "geo" => {
        "latitude" => 37.422,
        "longitude" => -122.084
      }
    })
    instance.to_hash.should == {
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day",
      "location" => "Googleplex",
      "url" => "http://www.piday.org/",
      "rrule" => "FREQ=YEARLY",
      "geo" => {
        "latitude" => 37.422,
        "longitude" => -122.084
      }
    }
  end

  it 'should convert to a JSON string' do
    instance = @calendar_parser.new({
      "dtstart" => "1592-03-14T00:00:00Z",
      "dtend" => "1592-03-14T23:59:59Z",
      "summary" => "Pi Day"
    })
    instance.to_json.should == (
      '{"dtend":"1592-03-14T23:59:59Z",' +
      '"dtstart":"1592-03-14T00:00:00Z",'+
      '"summary":"Pi Day"}'
    )
  end
end
