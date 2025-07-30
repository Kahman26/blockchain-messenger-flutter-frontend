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


class MessageDecryptWorker {
  final List<Map<String, dynamic>> rawMessages;
  final String privateKey;
  final void Function(List<Map<String, dynamic>> result) onDecrypted;

  MessageDecryptWorker({
    required this.rawMessages,
    required this.privateKey,
    required this.onDecrypted,
  });

  void decrypt() {
    throw UnsupportedError('MessageDecryptWorker is only supported on Web');
  }
}

