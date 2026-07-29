String generateVCard({
  required String name,
  String? email,
  String? organization,
  String? designation,
  String? mobile_number,
}) {
  final parts = name.trim().split(RegExp(r'\s+'));

  String family = '';
  String given = '';

  if (parts.length == 1) {
    given = parts.first;
  } else {
    family = parts.removeLast();
    given = parts.join(' ');
  }

  return '''
BEGIN:VCARD
VERSION:3.0
FN:$name
N:$family;$given;;;
${designation?.isNotEmpty == true ? 'TITLE:$designation' : ''}
${organization?.isNotEmpty == true ? 'ORG:$organization' : ''}
${mobile_number?.isNotEmpty == true ? 'TEL;TYPE=CELL:$mobile_number' : ''}
${email?.isNotEmpty == true ? 'EMAIL:$email' : ''}
END:VCARD
''';
}
