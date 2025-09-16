// lib/utils/vcard_util.dart

String generateVCard({
  required String name,
  required String email,
  required String organization,
  required String mobile_number,
}) {
  return "BEGIN:VCARD\n" +
      "VERSION:3.0\n" +
      "N:$name\n" +
      "FN:$name\n" +
      "EMAIL:$email\n" +
      "ORG:$organization\n" +
      "TEL;TYPE=CELL:$mobile_number\n" +
      "END:VCARD";
}
