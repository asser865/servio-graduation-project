/// A pair of strings for English and Arabic.
class BilingualText {
  const BilingualText({required this.en, required this.ar});

  final String en;
  final String ar;

  String of(String locale) => locale == 'ar' ? ar : en;
}
