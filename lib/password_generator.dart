import 'dart:math';

class PasswordOptions {
  const PasswordOptions({
    required this.useAlphabets,
    required this.useNumerics,
    required this.useSpecialCharacters,
    required this.length,
  });

  final bool useAlphabets;
  final bool useNumerics;
  final bool useSpecialCharacters;
  final int length;
}

class PasswordGenerator {
  static const String _alphabets = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numerics = '0123456789';
  static const String _specialCharacters = r'!@#%^&*()_+-=[]{}|;:,.<>?/~`';

  static String generate(PasswordOptions options) {
    final length = options.length.clamp(8, 256);

    final enabledSets = <String>[];
    if (options.useAlphabets) enabledSets.add(_alphabets);
    if (options.useNumerics) enabledSets.add(_numerics);
    if (options.useSpecialCharacters) enabledSets.add(_specialCharacters);

    if (enabledSets.isEmpty) enabledSets.add(_alphabets);

    final rnd = Random.secure();
    final chars = <String>[];

    // Ensure at least one from each enabled set.
    for (final set in enabledSets) {
      chars.add(set[rnd.nextInt(set.length)]);
    }

    final combined = enabledSets.join();
    while (chars.length < length) {
      chars.add(combined[rnd.nextInt(combined.length)]);
    }

    // Shuffle.
    for (var i = chars.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }

    return chars.join();
  }
}

