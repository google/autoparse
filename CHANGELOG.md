# 0.3.3

* Fixed issue with parent class redefinition

# 0.3.2

* Fixed issue with booleans and default values
* Fixed issue with class redefinition
* Updated Launchy dependency

# 0.3.1

* Replaced json gem dependency with multi_json
* Fixed issue with certain JSON libraries breaking on automatic #to_json calls

# 0.3.0

* Fixed handling of additional properties w/ a set schema
* Modified index methods to allow either raw or parsed access
* Modified index methods to default to parsed access

# 0.2.3

* Fixed stupid bug in inspect method

# 0.2.2

* The AutoParse.generate method was changed to use an options Hash
* Fixed some issues around array imports and exports
* Schemas of type object should now correctly inherit their id URI values

# 0.2.1

* Fixed URI resolution when base URI is missing

# 0.2.0

* Added support for union types
* Added support for recursive references
* Aixed vestigial code from refactoring extraction
* Fixed issue with references when schema URI is not supplied
* Fixed issue with missing gem dependencies

# 0.1.0

* Initial release
