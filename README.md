# Dogma Data

> A serialization library for Dart.

[![Join the chat at https://gitter.im/dogma-dart/dogma-dart.github.io](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/dogma-dart/dogma-dart.github.io?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](http://beta.drone.io/api/badges/dogma-dart/dogma-data/status.svg)](http://beta.drone.io/dogma-dart/dogma-data)
[![Coverage Status](https://coveralls.io/repos/dogma-dart/dogma-data/badge.svg?branch=master)](https://coveralls.io/r/dogma-dart/dogma-data?branch=master)

## Features
- Implicit (de)serialization of PODOs based on coding conventions.
- Explicit (de)serialization of PODOs using metadata annotations.
- Fully customizable (de)serialization behavior.
- Support for immutable views over models.

## Installation
Currently the Dogma Data library is in a pre-release state and should be
installed as a git dependency.

    # pubspec.yaml
    dependencies:
      dogma_data:
        git: git@github.com:dogma-dart/dogma-data.git

## Concepts
Dogma Data acts externally on Plain Old Dart Objects to perform the decoding
and encoding. This is done through ModelDecoder and ModelEncoder instances.
This separates the concerns of serialization from the model itself.

A simple example of obtaining a type's decoder and encoder follows.  

    library main;
    
    // \TODO EXAMPLE!
        
## Model Requirements
Dogma Data places restrictions on the type of data it can encode and decode.
This is to limit the problem space; keeping the complexity of the serialization
logic in check.
- Models must be Plain Old Dart Objects.
  - They cannot contain an extends clause, which also disallows mixins, but they can contain an implements clause.
  - They must contain a default constructor.
- Any values that can be automatically serialized require defined types.
  - A variable can not be of type dynamic.
  - If the variable is a generic then the type parameter(s) must be defined.
  - Use of final is not possible as only the default constructor will ever be called.
  
## Building a library
Dogma Data generates code directly without the use of a transformer. This means
that the code will be present within the library and can be debugged. The code
generation follows the convention of using a build.dart file within the package
which can be run directly or through the use of the
[build_system](https://github.com/a14n/build_system.dart) library.

A build.dart file can be generated by running `pub run dogma_data:init` which
will then prompt the user for information on the models. It will generate
the following when using the defaults.

    import 'package:dogma_data/build.dart';
    
    void main(List<String> args) {
      build(args, lib/models.dart);
    }

The build can be further customized through a number of optional parameters.
See the [docs](#) for further information. It is recommended for libraries that
will be publicly consumable to stick to the defaults.

## Implicit (De)Serialization

For simple cases the serialization can be automatically generated from the
model data. In this case any public member variables will be serialized into a
map where the key is the variable name.

The following shows a library containing a model that can be serialized.

    library models;
    
    class Person {
      String name = '';
      int age = 0;
    }

Map data that would be produced or consumed from the previous model looks like
the following.

    {
      "name": "Jane Doe",
      "age": 21
    }

When developing a first party application it is likely that implicit
serialization is all that is needed.

## Explicit (De)Serialization
Sometimes implicit serialization does not contain the required behavior from
the decoder and/or encoder. This is somewhat likely to occur when accessing a
third party API. To provide more control over the serialization process the
Dogma Data library allows explicit serialization options.

### Serialize
A Serialize is an annotation which maps a key to the member variable. This is
useful if the key within the map data does not correspond to the name within
the model.

The following shows a model where the Serialize.field annotation is used.

    class Person {
      @Serialize.field('full_name')
      String name;
      @Serialize.field('current_age')
      int age;
    }
    
Map data that would be produced or consumed from the previous model looks like
the following.

    {
      "full_name": "Jane Doe",
      "current_age": 21
    }

The Serialize.field annotation also has optional arguments which allow the
decoding or encoding of a field to be turned off. By default they are turned on.

__IMPORTANT! If there is a Serialize annotation present on a member variable
then all member variables to serialize require annotations. This is true even
if the name within the map is the same as the variable name. This is an all or
nothing operation.__

### Custom ModelDecoder or ModelEncoder
When decoding or encoding requires working on multiple values within the map
data or the model a custom ModelDecoder or ModelEncoder should be created. A
model can have as many decoders and encoders as necessary. Dogma Data will
combine the converters into a CompositeModelDecoder which will invoke the
individual conversion routines one by one.

__IMPORTANT! This declaration needs to be present within the same library as the model in order for the linkage to be detected. Also the ordering within the CompositeModelDecoder is not guaranteed so do not rely on data from the respective converter to be present.__

## Features and bugs
Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/dogma-dart/dogma-data/issues
