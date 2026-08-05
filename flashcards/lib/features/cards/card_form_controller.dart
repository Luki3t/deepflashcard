import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/cards_repository.dart';

class CardFormState {
  const CardFormState({
    this.sourceText = '',
    this.targetText = '',
    this.notes = '',
    this.exampleSentence,
    this.exampleTranslation,
    this.isSaving = false,
  });

  final String sourceText;
  final String targetText;
  final String notes;
  final String? exampleSentence;
  final String? exampleTranslation;
  final bool isSaving;

  bool get isValid =>
      sourceText.trim().isNotEmpty && targetText.trim().isNotEmpty;

  CardFormState copyWith({
    String? sourceText,
    String? targetText,
    String? notes,
    Object? exampleSentence = _sentinel,
    Object? exampleTranslation = _sentinel,
    bool? isSaving,
  }) => CardFormState(
    sourceText: sourceText ?? this.sourceText,
    targetText: targetText ?? this.targetText,
    notes: notes ?? this.notes,
    exampleSentence: exampleSentence == _sentinel
        ? this.exampleSentence
        : exampleSentence as String?,
    exampleTranslation: exampleTranslation == _sentinel
        ? this.exampleTranslation
        : exampleTranslation as String?,
    isSaving: isSaving ?? this.isSaving,
  );
}

const _sentinel = Object();

class CardFormNotifier extends Notifier<CardFormState> {
  @override
  CardFormState build() => const CardFormState();

  void setSourceText(String v) => state = state.copyWith(sourceText: v);
  void setTargetText(String v) => state = state.copyWith(targetText: v);
  void setNotes(String v) => state = state.copyWith(notes: v);

  void setExample(String? sentence, String? translation) => state = state
      .copyWith(exampleSentence: sentence, exampleTranslation: translation);

  Future<void> loadCard(int cardId) async {
    final card = await ref.read(cardsRepositoryProvider).getCardById(cardId);
    if (card != null) {
      state = state.copyWith(
        sourceText: card.sourceText,
        targetText: card.targetText,
        notes: card.notes ?? '',
        exampleSentence: card.exampleSentence,
        exampleTranslation: card.exampleTranslation,
      );
    }
  }

  Future<void> save(int deckId) async {
    if (!state.isValid || state.isSaving) return;
    state = state.copyWith(isSaving: true);
    try {
      final now = DateTime.now();
      await ref
          .read(cardsRepositoryProvider)
          .createCard(
            CardsCompanion.insert(
              deckId: deckId,
              sourceText: state.sourceText.trim(),
              targetText: state.targetText.trim(),
              notes: state.notes.trim().isEmpty
                  ? const Value(null)
                  : Value(state.notes.trim()),
              exampleSentence: Value(state.exampleSentence),
              exampleTranslation: Value(state.exampleTranslation),
              createdAt: now,
              nextReview: now,
            ),
          );
      state = const CardFormState();
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  Future<void> update(int cardId) async {
    if (!state.isValid || state.isSaving) return;
    state = state.copyWith(isSaving: true);
    try {
      await ref
          .read(cardsRepositoryProvider)
          .updateCardText(
            id: cardId,
            sourceText: state.sourceText.trim(),
            targetText: state.targetText.trim(),
            notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
            exampleSentence: state.exampleSentence,
            exampleTranslation: state.exampleTranslation,
          );
      state = const CardFormState();
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final cardFormProvider =
    NotifierProvider.autoDispose<CardFormNotifier, CardFormState>(
      CardFormNotifier.new,
    );
