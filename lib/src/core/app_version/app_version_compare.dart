/// Compare client version strings like 1.2.3+45 (semver + optional build).
int compareAppVersions(String a, String b) {
  final parsedA = _parse(a);
  final parsedB = _parse(b);

  for (var i = 0; i < 3; i++) {
    final cmp = parsedA.semver[i].compareTo(parsedB.semver[i]);
    if (cmp != 0) return cmp;
  }

  return parsedA.build.compareTo(parsedB.build);
}

bool isAppVersionLessThan(String current, String target) {
  return compareAppVersions(current, target) < 0;
}

class _ParsedVersion {
  _ParsedVersion(this.semver, this.build);

  final List<int> semver;
  final int build;
}

_ParsedVersion _parse(String version) {
  var value = version.trim();
  var build = 0;

  final plusIndex = value.indexOf('+');
  if (plusIndex >= 0) {
    final buildPart = value.substring(plusIndex + 1);
    value = value.substring(0, plusIndex);
    build = int.tryParse(buildPart) ?? 0;
  }

  final parts = value.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }

  return _ParsedVersion(parts.take(3).toList(), build);
}
