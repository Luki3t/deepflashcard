String normalizeForComparison(String text) {
  return text.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final dp = List.generate(
    a.length + 1,
    (i) => List.generate(b.length + 1, (j) => 0),
  );

  for (var i = 0; i <= a.length; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    dp[0][j] = j;
  }

  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
  }
  return dp[a.length][b.length];
}

/// Returns similarity 0.0–1.0 between two strings (after normalization).
double similarity(String a, String b) {
  final na = normalizeForComparison(a);
  final nb = normalizeForComparison(b);
  if (na == nb) return 1.0;
  if (na.isEmpty && nb.isEmpty) return 1.0;
  final maxLen = na.length > nb.length ? na.length : nb.length;
  if (maxLen == 0) return 1.0;
  return 1.0 - levenshtein(na, nb) / maxLen;
}
