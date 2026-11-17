/// Unit conversion for display. Storage is always metric.
library;

import 'models.dart';

double cToF(double c) => c * 9 / 5 + 32;
double fToC(double f) => (f - 32) * 5 / 9;
double kgToLb(double kg) => kg * 2.2046226;
double lbToKg(double lb) => lb / 2.2046226;

String fmtTemp(double c, TempUnit u) =>
    u == TempUnit.celsius ? '${c.toStringAsFixed(2)} °C' : '${cToF(c).toStringAsFixed(2)} °F';

String fmtWeight(double kg, WeightUnit u) =>
    u == WeightUnit.kg ? '${kg.toStringAsFixed(1)} kg' : '${kgToLb(kg).toStringAsFixed(1)} lb';
