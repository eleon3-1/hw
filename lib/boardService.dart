import 'package:cloud_firestore/cloud_firestore.dart';

class BoardService {
  static void connectEmulator(String host) {
    final firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator(host, 8080);
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveUserRecord({
    required String uid,
    required String firstName,
    required String lastName,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'role': 'user',
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> readMessages() {
    return _db.collection('messages').orderBy('createdAt').snapshots();
  }

  String newMessageId() {
    return _db.collection('messages').doc().id;
  }

  Future<void> createMessage({
    required String id,
    required String text,
    required String authorUid,
  }) async {
    final profile = await _db.collection('users').doc(authorUid).get();

    final authorName = '${profile.get('firstName')} ${profile.get('lastName')}';

    final reference = _db.collection('messages').doc(id);

    await _db.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);

      if (existing.exists) return;

      transaction.set(reference, {
        'text': text.trim(),
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
      });
    });
  }

  Future<void> updateMessage(String id, String text) async {
    await _db.collection('messages').doc(id).update({
      'text': text.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String id) async {
    await _db.collection('messages').doc(id).delete();
  }

  Future<void> readMessagesFromServer() async {
    await _db
        .collection('messages')
        .limit(1)
        .get(const GetOptions(source: Source.server));
  }
}
