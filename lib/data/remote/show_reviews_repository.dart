import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/model/show_comment.dart';
import '../local/settings_store.dart';

/// Encrypted-in-transit (TLS + Firebase Auth) show review & comment repository
/// backed by Cloud Firestore (`show_reviews/{dramaId}/comments/{uid}`).
class ShowReviewsRepository {
  final SettingsStore settingsStore;

  ShowReviewsRepository({required this.settingsStore});

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseAuth? get _auth => isFirebaseReady ? FirebaseAuth.instance : null;
  FirebaseFirestore? get _firestore =>
      isFirebaseReady ? FirebaseFirestore.instance : null;

  String? get currentUid => _auth?.currentUser?.uid;
  bool get isSignedIn => _auth?.currentUser != null;

  Future<List<ShowComment>> fetchComments(int dramaId) async {
    final fs = _firestore;
    if (fs == null || dramaId <= 0) return const [];
    try {
      final snap = await fs
          .collection('show_reviews')
          .doc('$dramaId')
          .collection('comments')
          .orderBy('updatedAt', descending: true)
          .limit(30)
          .get();
      return snap.docs
          .map((doc) => ShowComment.fromFirestore(doc.id, dramaId, doc.data()))
          .where((c) => c.content.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ShowComment> postOrUpdateComment({
    required int dramaId,
    required String content,
    required double rating,
    int? existingCreatedAt,
  }) async {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null) {
      throw StateError('Sign in with Google in Settings to post a review.');
    }

    final cleanContent = content.trim();
    if (cleanContent.isEmpty) {
      throw ArgumentError('Review text cannot be empty.');
    }
    if (cleanContent.length > 2000) {
      throw ArgumentError('Review must be 2,000 characters or fewer.');
    }

    final customName = settingsStore.state.customDisplayName.trim();
    final rawName = customName.isNotEmpty
        ? customName
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Moglog Member');
    final safeAuthor =
        rawName.length > 80 ? rawName.substring(0, 80) : rawName;
    final safePhoto = (user.photoURL ?? '').trim();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final comment = ShowComment(
      id: user.uid,
      dramaId: dramaId,
      uid: user.uid,
      author: safeAuthor,
      avatarUrl:
          safePhoto.isNotEmpty && safePhoto.length <= 500 ? safePhoto : null,
      content: cleanContent,
      rating: rating.clamp(0.0, 10.0),
      createdAt: existingCreatedAt ?? nowMs,
      updatedAt: nowMs,
    );

    await fs
        .collection('show_reviews')
        .doc('$dramaId')
        .collection('comments')
        .doc(user.uid)
        .set(comment.toFirestoreMap());

    return comment;
  }

  Future<void> deleteComment(int dramaId) async {
    final user = _auth?.currentUser;
    final fs = _firestore;
    if (user == null || fs == null) {
      throw StateError('Sign in with Google to delete your review.');
    }
    await fs
        .collection('show_reviews')
        .doc('$dramaId')
        .collection('comments')
        .doc(user.uid)
        .delete();
  }
}
