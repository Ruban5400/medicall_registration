// lib/utils/vcard_util.dart

String generateVCard({
  required String name,
  required String email,
  required String organization,
  required String role,
  required String mobile_number,
  required String address,
  required String reg_id,
}) {
  return "BEGIN:VCARD\n" +
      "VERSION:3.0\n" +
      "N:$name\n" +
      "FN:$name\n" +
      "EMAIL:$email\n" +
      "ORG:$organization\n" +
      "TITLE:$role\n" +
      "TEL;TYPE=CELL:$mobile_number\n" +
      "ADR:$address\n" +
      "REG_ID:$reg_id\n" +
      "END:VCARD";
}
