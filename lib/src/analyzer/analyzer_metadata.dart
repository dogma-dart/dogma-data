// Copyright (c) 2015, the Dogma Project Authors.
// Please see the AUTHORS file for details. All rights reserved.
// Use of this source code is governed by a zlib license that can be found in
// the LICENSE file.

/// Contains functions to generate metadata for codegen.
library dogma_data.src.codegen.codegen_metadata;

//---------------------------------------------------------------------
// Imports
//---------------------------------------------------------------------

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source_io.dart';

import 'package:dogma_data/serialize.dart';
import 'package:dogma_data/src/metadata/converter_metadata.dart';
import 'package:dogma_data/src/metadata/enum_metadata.dart';
import 'package:dogma_data/src/metadata/field_metadata.dart';
import 'package:dogma_data/src/metadata/function_metadata.dart';
import 'package:dogma_data/src/metadata/library_metadata.dart';
import 'package:dogma_data/src/metadata/model_metadata.dart';
import 'package:dogma_data/src/metadata/type_metadata.dart';

import 'annotation.dart';
import 'utils.dart';

//---------------------------------------------------------------------
// Library contents
//---------------------------------------------------------------------

LibraryMetadata libraryMetadata(String path, AnalysisContext context) {
  var source = new FileBasedSource(new JavaFile(path));

  return context.computeKindOf(source) == SourceKind.LIBRARY
      ? _libraryMetadata(context.computeLibraryElement(source), {})
      : null;
}

bool _shouldLoadLibraryMetadata(LibraryElement library) {
  var scheme = library.definingCompilationUnit.source.uri.scheme;

  return scheme != 'dart' && scheme != 'package';
}

LibraryMetadata _libraryMetadata(LibraryElement library, Map<String, LibraryMetadata> cached) {
  var name = library.name;

  if (cached.containsKey(name)) {
    return cached[name];
  }

  var importedLibraries = [];
  var exportedLibraries = [];

  // Look at the dependencies for metadata
  for (var imported in library.importedLibraries) {
    if (_shouldLoadLibraryMetadata(imported)) {
      importedLibraries.add(_libraryMetadata(imported, cached));
    }
  }

  for (var exported in library.exportedLibraries) {
    if (_shouldLoadLibraryMetadata(exported)) {
      exportedLibraries.add(_libraryMetadata(exported, cached));
    }
  }

  var models = [];
  var enumerations = [];
  var converters = [];
  var functions = [];
  var modelEncoders = [];
  var modelDecoders = [];
  var encodeFunctions = [];
  var decodeFunctions = [];

  for (var unit in library.units) {
    for (var type in unit.types) {
      var metadata = modelMetadata(type);

      if (metadata != null) {
        models.add(metadata);
      } else {
        metadata = converterMetadata(type);

        if (metadata != null) {
          converters.add(metadata);
        }
      }
    }

    for (var function in unit.functions) {
      var metadata = functionMetadata(function);

      if (metadata != null) {
        functions.add(metadata);
      }
    }

    for (var enumeration in unit.enums) {
      var metadata = enumMetadata(enumeration);

      if (metadata != null) {
        enumerations.add(metadata);
      }
    }
  }

  // Create metadata if there was anything discovered
  //
  // Rather than doing an isEmpty on each of the lists the length is used and
  // if that length is greater than 0 then an instance of LibraryMetadata
  // should be created.
  var metadataCount =
      importedLibraries.length +
      exportedLibraries.length +
      models.length +
      enumerations.length +
      converters.length +
      functions.length +
      modelEncoders.length +
      modelDecoders.length +
      encodeFunctions.length +
      decodeFunctions.length;

  if (metadataCount > 0) {
    var metadata = new LibraryMetadata(
        name,
        library.definingCompilationUnit.name,
        imported: importedLibraries,
        exported: exportedLibraries,
        models: models,
        enumerations: enumerations,
        converters: converters,
        functions: functions
    );

    cached[name] = metadata;

    return metadata;
  } else {
    return null;
  }
}

ModelMetadata modelMetadata(ClassElement element) {
  var implicit = true;
  var fields = [];

  // Iterate over the fields within the class
  for (var field in element.fields) {
    if (_isSerializableField(field)) {
      var decode = implicit;
      var encode = implicit;
      Serialize serialize;

      // Iterate over the metadata looking for annotations
      for (var metadata in field.metadata) {
        serialize = annotation(metadata);

        if (serialize != null) {
          decode = serialize.decode;
          encode = serialize.encode;

          // An annotation was encountered so switch to explicit serialization
          if (implicit) {
            fields.clear();
            implicit = false;
          }

          break;
        }
      }

      // Add the field if serializable
      if ((decode) || (encode)) {
        var type = typeMetadata(field.type);
        var serializationName = serialize?.name;
        fields.add(new FieldMetadata(field.name, type, decode, encode, serializationName: serializationName));
      }
    }
  }

  return (fields.length > 0)
      ? new ModelMetadata(element.name, fields)
      : null;
}

bool _isSerializableField(FieldElement element) {
  return
      !element.isPrivate &&
      !element.isStatic &&
      !element.isFinal &&
      !element.isConst;
}

TypeMetadata typeMetadata(DartType type) {
  var arguments = [];

  if (type is InterfaceType) {
    for (var argument in type.typeArguments) {
      arguments.add(typeMetadata(argument));
    }
  }

  return new TypeMetadata(type.name, arguments: arguments);
}

EnumMetadata enumMetadata(ClassElement element) {
  // Find all the enumerations within the element
  //
  // The analyzer appears to always have this in ascending order so no sorting
  // is required
  var enumerations = enumValues(element);
  var enumerationCount = enumerations.length;
  var encoded;

  // Look to see if the mapping is explicitly stated.
  //
  // Currently annotations have to appear on the class itself rather than on
  // individual values. So search the annotations at the class level.
  var metadata = findAnnotation(element);

  if (metadata != null) {
    var decode = metadata.mapping;
    encoded = new List(enumerationCount);

    decode.forEach((key, value) {
      var index = enumerations.indexOf(value);
      encoded[index] = key;
    });
  }

  var values = [];
  for (var enumeration in enumerations) {
    values.add(enumeration.name);
  }

  return new EnumMetadata(element.name, values, encoded: encoded);
}

ConverterMetadata converterMetadata(ClassElement element) {
  // Iterate over the interfaces
  for (var interface in element.interfaces) {
    var name = interface.name;
    var decoder = name == 'ModelDecoder';
    var type;

    if ((decoder) || (name == 'ModelEncoder')) {
      type = typeMetadata(interface.typeArguments[0]);
    }

    if (type != null) {
      return new ConverterMetadata(name, type, decoder);
    }
  }

  return null;
}

FunctionMetadata functionMetadata(FunctionElement element) {
  var parameters = element.parameters;

  // See if the function is valid as an encoder or decoder
  if (parameters.length == 1) {
    var metadata = findAnnotation(element);
    var decoder;

    if (metadata != null) {
      // \TODO Error check for unknown Serialize instance?
      if (metadata == Serialize.decodeThrough) {
        decoder = true;
      } else if (metadata == Serialize.encodeThrough) {
        decoder = false;
      }
    }

    var input = typeMetadata(parameters[0].type);
    var output = typeMetadata(element.returnType);

    return new FunctionMetadata(element.name, input, output, decoder: decoder);
  } else {
    return null;
  }
}
