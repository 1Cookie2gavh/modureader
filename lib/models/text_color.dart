/// Empty means the existing reading palette / original text colour.
bool validTextColor(Object? value) =>
    value is String &&
    (value.isEmpty || RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value));

const textColorPresets = [
  '#343434',
  '#287D75',
  '#287FA3',
  '#546E52',
  '#8B5E3C',
  '#785A9B',
  '#B24D49',
  '#D8D8D8',
];
