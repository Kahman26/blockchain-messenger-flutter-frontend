class KeyGenWorker {
  final void Function(Map<String, String>) onKeysAndEncryptedReady;

  KeyGenWorker({required this.onKeysAndEncryptedReady});

  void generateKeys() {
    throw UnsupportedError('KeyGenWorker is only available on web');
  }
}

class DecryptWorker {
  final String encrypted;
  final String mnemonic;
  final void Function(String result) onDecrypted;

  DecryptWorker({
    required this.encrypted,
    required this.mnemonic,
    required this.onDecrypted,
  });

  void decrypt() {
    throw UnsupportedError('DecryptWorker is only available on web');
  }
}
