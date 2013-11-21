/**
 * Provides the [Exportable] mixin class.
 */
library exportable;

import 'dart:mirrors';
import 'dart:convert' show JSON;

/**
 * A mixin providing an ability to export objects to [Map]s or JSON.
 *
 * Object properties could be
 *
 * * any type supported by JSON (see [JsonEncoder.convert()])
 * * any calss that mixes [Exportable]
 * * [DateTime]
 *
 * Usage example:
 *
 *     class Foo extends Object with Exportable {
 *       String bar;
 *     }
 *
 *     void main() {
 *       Foo foo = new Exportable(Foo); // The same as "new Foo()".
 *       foo.bar = 'Bar';
 *       print(foo.toMap()); // {bar: Bar}
 *       print(foo.toJson()); // {"bar":"Bar"}
 *       print(foo.toString()); // {"bar":"Bar"}
 *       Foo baz = new Exportable(Foo, '{"bar":"Baz"}');
 *       print(baz); // {"bar":"Baz"}
 *       Foo baz2 = new Exportable(Foo, {'bar': 'Baz'});
 *       print(baz2); // {"bar":"Baz"}
 *     }
 *
 */
class Exportable {

  /**
   * Creates a new objects instance, calling the default constructor.
   *
   * If [init] (could be [String] or [Map]) is passed, it's used for initialize
   * object proprties.
   */
  factory Exportable(Type type, [init]) {
    var instance = reflectClass(type).newInstance(new Symbol(''), []).reflectee;
    if (instance is! Exportable) {
      throw new Exception('Type $type is not mixing Exportable.');
    }
    if (init is Map) {
      instance.initFromMap(init);
    } else if (init is String) {
      instance.initFromJson(init);
    }
    return instance;
  }

  void initFromMap(Map map) {
    InstanceMirror thisMirror = reflect(this);
    map.forEach((name, value) {
      Symbol symbol = new Symbol(name);
      Map<Symbol, VariableMirror> declarations = _collectPublicVariableMirrors(thisMirror.type);
      if (declarations.containsKey(symbol)) {
        VariableMirror declaration = declarations[symbol];
        if (declaration.type is ClassMirror) {
          Type type = (declaration.type as ClassMirror).reflectedType;
          if (_isExportable(declaration.type)) {
            thisMirror.setField(symbol, new Exportable(type, value));
          } else {
            thisMirror.setField(symbol, _importSimpleValue(type, value));
          }
        }
      }
    });
  }

  void initFromJson(String json) {
    try {
      var map = JSON.decode(json);
      if (map is Map) {
        initFromMap(map);
      }
    } catch (e) {}
  }

  Map toMap() {
    Map map = {};
    InstanceMirror thisMirror = reflect(this);
    _collectPublicVariableMirrors(thisMirror.type).forEach((Symbol symbol, VariableMirror declaration) {
      var value = thisMirror.getField(symbol).reflectee;
      map[MirrorSystem.getName(symbol)] = value is Exportable
          ? value.toMap() : _exportSimpleValue(value);
    });
    return map;
  }

  String toJson() {
    return JSON.encode(toMap());
  }

  /**
   * An alias for [toJson].
   */
  String toString() {
    return toJson();
  }

  dynamic operator [](String propertyName) {
    InstanceMirror thisMirror = reflect(this);
    Symbol symbol = new Symbol(propertyName);
    if (_fieldExists(symbol, thisMirror.type)) {
      return thisMirror.getField(symbol).reflectee;
    }
    return null;
  }

  void operator []=(String propertyName, dynamic value) {
    InstanceMirror thisMirror = reflect(this);
    Symbol symbol = new Symbol(propertyName);
    if (_fieldExists(symbol, thisMirror.type)) {
      thisMirror.setField(symbol, value);
    }
  }

  static bool _fieldExists(Symbol fieldSymbol, ClassMirror classMirror) {
    return _collectPublicVariableMirrors(classMirror).containsKey(fieldSymbol);
  }

  static dynamic _exportSimpleValue(value) {
    if (_isJsonSupported(value)) {
      return value;
    } else if (value is DateTime) {
      return (value as DateTime).toUtc().toString();
    }
    return null;
  }

  static dynamic _importSimpleValue(Type type, value) {
    if (type == DateTime && value is String) {
      return DateTime.parse(value).toLocal();
    } else if (_isJsonSupported(value)) {
      return value;
    }
    return null;
  }

  static bool _isJsonSupported(value) {
    if (value == null
        || value is bool
        || value is num
        || value is String
        || value is List
        || value is Map) {
      return true;
    }
    return false;
  }

  static bool _isExportable(ClassMirror classMirror) {
    List<ClassMirror> allClassMirrors = _getAllClassMirrors(classMirror);
    for (var i = 0; i < allClassMirrors.length; i++) {
      if (allClassMirrors[i].hasReflectedType
          && allClassMirrors[i].reflectedType == Exportable) {
        return true;
      }
    }
    return false;
  }

  static Map<Symbol, VariableMirror> _collectPublicVariableMirrors(ClassMirror classMirror) {
    Map<Symbol, VariableMirror> map = {};
    _getAllClassMirrors(classMirror).forEach((ClassMirror classMirror_) {
      classMirror_.declarations.forEach((Symbol symbol, DeclarationMirror declaration) {
        if (declaration is VariableMirror && !declaration.isPrivate) {
          map[symbol] = declaration;
        }
      });
    });
    return map;
  }

  static List<ClassMirror> _getAllClassMirrors(ClassMirror classMirror) {
    List<ClassMirror> list = [];
    if (!list.contains(classMirror)) {
      list.add(classMirror);
    }
    if (classMirror.superclass is ClassMirror) {
      list.addAll(_getAllClassMirrors(classMirror.superclass));
    }
    if (classMirror.mixin != classMirror && classMirror.mixin is ClassMirror) {
      list.addAll(_getAllClassMirrors(classMirror.mixin));
    }
    return list;
  }

  static Map<Map<String, dynamic>, dynamic> _cache_ = {};
  static dynamic _cache(String type, key, [value]) {
    Map<String, dynamic> id = {type: key};
    if (value == null) {
      if (_cache_.containsKey(id)) {
        return _cache_[id];
      }
    } else {
      _cache_[id] = value;
    }
    return value;
  }
}
