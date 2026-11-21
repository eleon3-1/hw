import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'boardService.dart';
import 'main.dart' show AuthService;

class BoardScreen extends StatefulWidget {
  final AuthService auth;

  const BoardScreen({super.key, required this.auth});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardService board = BoardService();
  final message = TextEditingController();

  late final String uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> messages;

  String? pendingId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    uid = widget.auth.currentUser!.uid;
    messages = board.readMessages();
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> runAction(Future<void> Function() action) async {
    if (busy) return;

    setState(() {
      busy = true;
    });

    try {
      await action();
    } on FirebaseException catch (e) {
      showMessage('didnt work: ${e.code}');
    } catch (_) {
      showMessage('couldnt finish that');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> postMessage() async {
    final text = message.text.trim();

    if (text.isEmpty) {
      showMessage('type a message first');
      return;
    }

    pendingId ??= board.newMessageId();
    final id = pendingId!;

    await runAction(() async {
      await board.createMessage(id: id, text: text, authorUid: uid);

      if (mounted) {
        message.clear();
        pendingId = null;
      }
    });
  }

  Future<void> testDuplicateWrite() async {
    final text = message.text.trim();

    if (text.isEmpty) {
      showMessage('type a message first');
      return;
    }

    pendingId ??= board.newMessageId();
    final id = pendingId!;

    await runAction(() async {
      await board.createMessage(id: id, text: text, authorUid: uid);

      await board.createMessage(id: id, text: text, authorUid: uid);

      if (mounted) {
        message.clear();
        pendingId = null;
        showMessage('two calls, same message id');
      }
    });
  }

  Future<void> editMessage(String id, String original) async {
    String edited = original;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('edit message'),
          content: TextFormField(
            initialValue: original,
            onChanged: (value) {
              edited = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, edited.trim());
              },
              child: const Text('save'),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) return;

    if (result.isEmpty) {
      showMessage('type a message first');
      return;
    }

    await runAction(() => board.updateMessage(id, result));
  }

  Future<void> testOtherUserWrites(String id, String text) async {
    await runAction(() async {
      String editResult = 'edit was allowed';
      String deleteResult = 'delete was allowed';

      try {
        await board.updateMessage(id, text);
      } on FirebaseException catch (e) {
        editResult = 'edit: ${e.code}';
      }

      try {
        await board.deleteMessage(id);
      } on FirebaseException catch (e) {
        deleteResult = 'delete: ${e.code}';
      }

      showMessage('$editResult\n$deleteResult');
    });
  }

  Future<void> testSignedOutRead() async {
    final messenger = ScaffoldMessenger.of(context);

    await runAction(() async {
      await widget.auth.signOut();

      String result = 'signed out read was allowed';

      try {
        await board.readMessagesFromServer();
      } on FirebaseException catch (e) {
        result = 'signed out read: ${e.code}';
      }

      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(result)));
      }
    });
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Msgboard'),
        actions: [
          TextButton(
            onPressed: busy ? null : () => runAction(widget.auth.signOut),
            onLongPress: busy ? null : testSignedOutRead,
            child: const Text('sign out'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;

                  return Center(
                    child: Text(
                      error is FirebaseException
                          ? 'cant load messages: ${error.code}'
                          : 'cant load messages',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final documents = snapshot.data!.docs;

                if (documents.isEmpty) {
                  return const Center(child: Text('no messages yet'));
                }

                return ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final data = document.data();
                    final ownMessage = data['authorUid'] == uid;

                    return ListTile(
                      onLongPress: busy || ownMessage
                          ? null
                          : () => testOtherUserWrites(
                              document.id,
                              data['text'] as String,
                            ),
                      title: Text(data['text'] as String),
                      subtitle: Text(data['authorName'] as String),
                      trailing: ownMessage
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: busy
                                      ? null
                                      : () => editMessage(
                                          document.id,
                                          data['text'] as String,
                                        ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: busy
                                      ? null
                                      : () => runAction(
                                          () =>
                                              board.deleteMessage(document.id),
                                        ),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    enabled: !busy,
                    onChanged: (_) {
                      pendingId = null;
                    },
                    decoration: const InputDecoration(labelText: 'message'),
                  ),
                ),
                ElevatedButton(
                  onPressed: busy ? null : postMessage,
                  onLongPress: busy ? null : testDuplicateWrite,
                  child: Text(busy ? 'wait' : 'post'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
