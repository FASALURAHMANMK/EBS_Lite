import 'dart:convert';
T decodeJson<T>(String s) => jsonDecode(s) as T;
String encodeJson(Object v) => jsonEncode(v);