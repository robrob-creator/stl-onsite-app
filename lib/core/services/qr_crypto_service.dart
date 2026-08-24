import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

/// Encrypts QR code data so only this app can decode a scanned ticket number.
/// External scanners see opaque ciphertext prefixed with [_prefix].
class QrCryptoService {
  // 32-byte key (AES-256). Change this to invalidate all previously printed QRs.
  static const String _rawKey = r'STL@4Pl@yT3ch!QR#2026$Secure_Key';
  static const String _prefix = 'STL:';

  static final Key _key = Key(Uint8List.fromList(
    utf8.encode(_rawKey).sublist(0, 32),
  ));

  // Fixed IV — deterministic so the same ticket always produces the same QR.
  static final IV _iv = IV(Uint8List.fromList(utf8.encode('STL!IV@4Play!16b')));

  static final Encrypter _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  /// Returns encrypted, prefixed string for use as QR data.
  static String encrypt(String ticketNo) {
    final encrypted = _encrypter.encrypt(ticketNo, iv: _iv);
    return '$_prefix${encrypted.base64}';
  }

  /// Returns original ticket number. Returns [raw] unchanged if not encrypted by us.
  static String decrypt(String raw) {
    if (!raw.startsWith(_prefix)) return raw;
    try {
      final b64 = raw.substring(_prefix.length);
      return _encrypter.decrypt64(b64, iv: _iv);
    } catch (_) {
      return raw;
    }
  }

  static bool isEncrypted(String value) => value.startsWith(_prefix);
}
