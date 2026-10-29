
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  print('mr supported in GlobalMaterialLocalizations: ' +
    GlobalMaterialLocalizations.delegate.isSupported(const Locale('mr')).toString());
  print('hi supported in GlobalMaterialLocalizations: ' +
    GlobalMaterialLocalizations.delegate.isSupported(const Locale('hi')).toString());
}
