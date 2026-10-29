
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  print('mr supported in Cupertino: ' +
    GlobalCupertinoLocalizations.delegate.isSupported(const Locale('mr')).toString());
  print('mr supported in Material: ' +
    GlobalMaterialLocalizations.delegate.isSupported(const Locale('mr')).toString());
}
