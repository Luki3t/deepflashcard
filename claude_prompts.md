# Aplikacja Fiszek we Flutterze — Prompty dla Claude Code

Komplet promptów do zbudowania aplikacji krok po kroku. Każdy etap buduje na poprzednim — używaj ich w kolejności. Po każdym promptcie uruchom aplikację i sprawdź, czy działa, zanim przejdziesz dalej.

---

## Specyfikacja projektu

**Funkcje MVP:**
- Wybór języka ojczystego i języka nauki na start
- Dodawanie fiszek ręcznie (słowo + tłumaczenie wpisane przez użytkownika)
- Spaced Repetition Algorithm (SM-2 — jak w Anki)
- Talie/kategorie fiszek
- Tryby nauki: flip, quiz wyboru, wpisywanie odpowiedzi
- Statystyki + streak (dzienna passa)
- Ciemny motyw

**Automatyzacja (dodawana stopniowo w Phase 3):**
- Auto-tłumaczenie (Google ML Kit, on-device, bezpłatne)
- Wymowa TTS
- Przykładowe zdania z Tatoeba (lokalna baza, offline)

**Platforma:** Android (MVP), iOS później przez Codemagic.

**Filozofia architektury:** Wszystko działa na urządzeniu użytkownika. Brak serwera, brak płatnych API, brak kluczy. Koszty operacyjne = $0.

**Stos technologiczny:**
- Flutter (stable)
- Riverpod 2.x — state management
- drift — type-safe SQLite
- go_router — nawigacja
- google_mlkit_translation — tłumaczenia on-device (Phase 3)
- flutter_tts — wymowa (Phase 3)
- flutter_local_notifications — przypomnienia (Phase 4)

---

## Co musisz przygotować zanim zaczniesz

1. Flutter SDK + Android Studio z emulatorem (API 24+)
2. VS Code z rozszerzeniami Flutter i Dart (lub Android Studio)
3. Konto GitHub (opcjonalnie, do backupu)

**Żadnych kluczy API nie potrzebujesz dla MVP.** Cała aplikacja działa offline.

---

## Wskazówki przy korzystaniu z Claude Code

1. **Jeden prompt = jeden etap.** Nie wklejaj wszystkiego na raz.
2. **Po każdym etapie testuj.** `flutter run` na emulatorze, kliknij po aplikacji.
3. **Gdy coś nie działa** — opisz Claude Code: "On step X, when I do Y, I get Z. Fix it."
4. **Commity po każdym etapie.** `git add . && git commit -m "prompt N: ..."` — łatwo cofnąć.
5. **Zawsze:** `flutter analyze` po każdym etapie, zero warningów przed przejściem dalej.

---

# PHASE 1 — Ręczny rdzeń (działa bez internetu i bez AI)

> Po tej fazie masz działającą aplikację do fiszek. Możesz dodawać talie, dodawać fiszki ręcznie i uczyć się z algorytmem SM-2.

---

## ✅ Prompt 1 — Setup projektu i struktura (DONE)

Projekt został już stworzony. Folder `flashcards/` zawiera:
- Flutter project z wszystkimi zależnościami w `pubspec.yaml`
- Folder structure: `lib/core/`, `lib/data/`, `lib/features/`, `lib/services/`
- Material 3 theme (light + dark), go_router, Riverpod wired up

---

## ✅ Prompt 2 — Schemat bazy danych z drift (DONE)

```
Set up the drift database for the flashcard app.

File: lib/data/database/app_database.dart

Create these tables:

1. decks
   - id (autoIncrement, primary key)
   - name (text, not null)
   - description (text, nullable)
   - source_language (text, not null)  -- e.g. 'pl'
   - target_language (text, not null)  -- e.g. 'en'
   - created_at (DateTime, not null)
   - updated_at (DateTime, not null)

2. cards
   - id (autoIncrement, primary key)
   - deck_id (int, foreign key → decks.id, ON DELETE CASCADE)
   - source_text (text, not null)
   - target_text (text, not null)
   - notes (text, nullable)
   - created_at (DateTime, not null)
   -- SM-2 fields:
   - ease_factor (real, default 2.5)
   - interval_days (int, default 0)
   - repetitions (int, default 0)
   - next_review (DateTime, not null)  -- defaults to now
   - last_reviewed (DateTime, nullable)

3. review_logs
   - id (autoIncrement, primary key)
   - card_id (int, foreign key → cards.id, ON DELETE CASCADE)
   - reviewed_at (DateTime, not null)
   - rating (int, not null)           -- 0–5 SM-2 rating
   - previous_interval (int, not null)
   - new_interval (int, not null)

4. user_stats (single-row table)
   - id (int, primary key, always 1)
   - current_streak (int, default 0)
   - longest_streak (int, default 0)
   - last_study_date (DateTime, nullable)
   - total_reviews (int, default 0)

Steps:
1. Write the drift table classes and AppDatabase in lib/data/database/app_database.dart
2. Run: dart run build_runner build --delete-conflicting-outputs
3. Create lib/data/database/database_provider.dart — Riverpod provider for AppDatabase (singleton, lazy)
4. Fill in the repository stubs in lib/data/repositories/:
   - DecksRepository: watchAllDecks() stream, getDeckById(), createDeck(), updateDeck(), deleteDeck()
   - CardsRepository: watchCardsForDeck(deckId), getCardById(), createCard(), updateCard(), deleteCard(), getDueCards(deckId, DateTime now)
   - ReviewsRepository: logReview(), getReviewsForDate(DateTime)
   - StatsRepository: getStats(), updateStreak(DateTime today), incrementTotalReviews()
   Each repository is exposed as a Riverpod provider.
5. Enable foreign key support: in AppDatabase constructor call customStatement('PRAGMA foreign_keys = ON').
6. schemaVersion = 1, add empty MigrationStrategy for now.

After implementation write a quick smoke-test in a main() or a Dart test:
create a deck → add a card → query due cards → verify it returns the card.

Run flutter analyze — zero issues before moving on.
```

---

## ✅ Prompt 3 — Onboarding: wybór języków (DONE)

```
Build the onboarding flow. Keep it simple — language selection only, no model downloads.

Flow:
- On app start read shared_preferences key 'onboarding_completed' (bool).
- If missing/false → show onboarding.
- If true → go to home screen ('/').

Onboarding screens (use go_router, bottom progress dots):
1. /onboarding/welcome  — app name "Flashcards", tagline "Learn words, remember them.", "Get Started" button.
2. /onboarding/native   — "What is your native language?" — scrollable list, flag emoji + language name.
3. /onboarding/target   — "What language do you want to learn?" — same list, can't pick same as native.
4. /onboarding/confirm  — "I speak [X], I want to learn [Y]" — "Start Learning" button.
   On confirm:
   - Save 'onboarding_completed' = true
   - Save 'native_language_code' and 'target_language_code'
   - Create a default deck named "My First Deck" with those languages
   - Navigate to '/'

Supported languages (ML Kit compatible subset):
  English (en), Polish (pl), German (de), Spanish (es), French (fr),
  Italian (it), Portuguese (pt), Russian (ru), Ukrainian (uk),
  Chinese (zh), Japanese (ja), Korean (ko), Dutch (nl), Swedish (sv),
  Norwegian (no), Czech (cs), Slovak (sk), Hungarian (hu), Turkish (tr)

Implementation:
- lib/features/onboarding/ — screens + OnboardingController (Riverpod Notifier)
- LanguagePreferencesProvider (Riverpod) — exposes current native/target codes app-wide
- Language preferences must be changeable later from Settings

UI: Material 3, clean and minimal. ListView with flag emoji + language name rows.
Add a "Back" button on steps 2–4.

Run flutter analyze — zero issues.
```

---

## ✅ Prompt 4 — App shell i lista talii (DONE)

```
Build the main app shell and the decks list screen.

1. App shell — BottomNavigationBar with 3 tabs:
   - Decks (Icons.style)         → '/'
   - Study (Icons.school)        → '/study/all'  (placeholder for now)
   - Stats (Icons.bar_chart)     → '/stats'      (placeholder for now)
   Keep a settings icon in the AppBar (top-right) → '/settings' (placeholder).

2. Decks screen ('/'):
   - AppBar: "My Decks"
   - Use watchAllDecks() stream → reactive list.
   - Each deck card shows:
       • Deck name
       • "PL → EN" language pair
       • Total cards count
       • Due today count (badge, highlighted if > 0)
   - Tap deck → '/decks/:id'
   - FAB: "+ New Deck" → opens CreateDeckDialog
   - Empty state: friendly message + "Create Your First Deck" button.

3. CreateDeckDialog (bottom sheet or dialog):
   - Name field (required)
   - Description field (optional)
   - Source language dropdown (defaults to native from LanguagePreferencesProvider)
   - Target language dropdown (defaults to target from LanguagePreferencesProvider)
   - Save / Cancel

4. Deck detail screen ('/decks/:id'):
   - AppBar: deck name + overflow menu (Edit, Delete with confirmation)
   - Summary row: total cards · due today · new cards
   - "Study Now" button (disabled if 0 due + 0 new)
   - Card list: each row shows source_text → target_text
   - FAB: "+ Add Card" → '/decks/:id/add-card' (placeholder screen for now)
   - Empty state: "No cards yet. Tap + to add your first card."

5. Proper loading (CircularProgressIndicator) and error states everywhere.

Run flutter analyze — zero issues.
```

---

## ✅ Prompt 5 — Dodawanie fiszek ręcznie (DONE)

```
Build the Add Card screen. No translation — the user types both sides manually.

Screen: '/decks/:id/add-card'

Layout:
- AppBar: "Add Card" + Save button (top-right, disabled until both fields are non-empty)
- Language hint below AppBar: "Polish → English" (from deck's languages)
- TextField "Word or phrase" (source language label)
- TextField "Translation" (target language label)
- TextField "Notes (optional)"
- After saving: show SnackBar "Card added ✓", clear all fields, keep screen open so user can add more cards quickly.
- Back arrow → deck detail.

Edit mode ('/decks/:id/edit-card/:cardId'):
- Pre-fill fields from existing card.
- AppBar: "Edit Card" + Save button.
- Extra option in deck detail card row: long-press or swipe → Edit / Delete actions.

Implementation:
- lib/features/cards/add_card_screen.dart
- CardFormController (Riverpod Notifier) — handles state, validation, save.
- On save: CardsRepository.createCard() with default SM-2 values (ease=2.5, interval=0, reps=0, next_review=now).
- On delete from deck detail: show confirmation dialog "Remove this card?", then CardsRepository.deleteCard().

Run flutter analyze — zero issues. Test: add 5 cards to a deck, verify they appear in the list.
```

---

## ✅ Prompt 6 — Algorytm SM-2 i tryb Flip Card (DONE)

```
Implement the SM-2 spaced repetition algorithm and the Flip Card study mode.

1. SM-2 algorithm — lib/features/study/srs_algorithm.dart (pure functions, no Flutter deps):

   class SrsResult {
     final int intervalDays;
     final int repetitions;
     final double easeFactor;
     final DateTime nextReview;
   }

   SrsResult applySM2(Card card, int rating, DateTime now):
     Rating scale: 0=Again, 3=Hard, 4=Good, 5=Easy
     - rating < 3:  repetitions=0, interval=1
     - rating >= 3:
         if reps==0: interval=1
         if reps==1: interval=6
         else:       interval=round(prev_interval * ease_factor)
         repetitions += 1
     - new EF = EF + 0.1 - (5-rating)*(0.08 + (5-rating)*0.02)
     - clamp EF to minimum 1.3
     - nextReview = now + intervalDays days

   Write unit tests for all edge cases (again resets, EF floor, intervals).

2. StudySessionNotifier (Riverpod AsyncNotifier) in lib/features/study/:
   - Takes deckId (int? — null means all decks).
   - Loads: getDueCards(deckId, now) + up to maxNewCardsPerDay new cards (reps==0 && interval==0).
   - State: { cards: List<Card>, index: int, sessionStats: {reviewed, correct, again} }
   - Methods:
       submitRating(int rating): applies SM-2, updates card via CardsRepository, logs via ReviewsRepository, advances index.
       When last card done: call StatsRepository.updateStreak(today) + incrementTotalReviews(count).

3. Study screen — Flip Card mode ('/decks/:id/study' or '/study/all'):
   - Top: LinearProgressIndicator (index/total) + row "✓ X  ✗ Y"
   - Center: large Card widget
       Front: source_text (big, centered)
       Tap → flip animation (use AnimatedSwitcher with a custom 3D flip) → back shows target_text + notes
   - Bottom: 4 rating buttons (show only AFTER flip):
       [Again] red   → 0
       [Hard]  amber → 3
       [Good]  green → 4
       [Easy]  blue  → 5
       Each button shows resulting interval below: "1d", "6d", etc.
   - After rating → short slide animation to next card.
   - Session summary screen when done:
       "Session complete! X cards reviewed, Y correct."
       "Back to Deck" button.

4. Wire up "Study Now" button in deck detail → navigates to study screen.
   Wire up Study tab in BottomNavigationBar → '/study/all'.

Run flutter analyze — zero issues. Test a full session with 5 cards.
```

---

## ✅ Prompt 7 — Statystyki i streak (DONE)

```
Build the Statistics screen and streak tracking.

1. Streak logic (already called from StudySessionNotifier after each session):
   StatsRepository.updateStreak(DateTime today):
   - last_study_date == today     → no change
   - last_study_date == yesterday → current_streak += 1
   - older or null                → current_streak = 1
   - if current_streak > longest_streak → update longest_streak
   - set last_study_date = today

2. Stats screen ('/stats'):
   - Hero at top: "🔥 X day streak" (large, colored)
   - Grid of stat cards:
       • Total cards (all decks)
       • Due today (all decks)
       • Cards learned (repetitions >= 3)
       • Total reviews all-time
       • Longest streak
   - Heatmap: last 90 days review activity
       Use flutter_heatmap_calendar package OR build a simple GridView with colored cells (0=grey, 1-3=light, 4+=dark).
       Source data: ReviewsRepository.getReviewsInRange(start, end) grouped by date.
   - Per-deck breakdown: list with progress bar (% cards with reps >= 3).

3. Today's progress widget on Home screen (Decks tab):
   - Small card at top: "Today: X / Y cards reviewed" with a thin LinearProgressIndicator.
   - Y = cards due today across all decks.
   - Only show if Y > 0.

4. Add flutter_heatmap_calendar to pubspec.yaml if using that package.

Run flutter analyze — zero issues.
After this prompt you have a complete, usable flashcard app — no internet required.
```

---

# PHASE 2 — Dodatkowe tryby nauki

---

## ✅ Prompt 8 — Quiz wyboru i Wpisywanie odpowiedzi (DONE)

```
Add two more study modes: Multiple Choice and Typing.

1. Mode selection screen — shown when user taps "Study Now":
   Three large selectable cards:
   - 🃏 Flip Cards
   - 🔤 Multiple Choice
   - ⌨️  Typing
   Save preferred mode per deck in shared_preferences key 'deck_{id}_study_mode'.

2. Multiple Choice mode:
   - Shows source_text + 4 answer buttons (target language).
   - 1 correct + 3 distractors (random cards from same deck; if deck < 4 cards → fallback to Flip mode with a message).
   - Correct tap → green flash, auto-rate 4 (Good), advance.
   - Wrong tap → red flash on chosen, green on correct, rate 0 (Again), "Continue" button.
   - Reuse StudySessionNotifier from Prompt 6.

3. Typing mode:
   - Shows source_text at top.
   - TextField "Type the translation..." + Submit button (or Enter key).
   - Comparison (normalizeForComparison from lib/core/utils/string_utils.dart):
       • Exact match (after normalize) → green, rate 5 (Easy).
       • Similarity > 80% (Levenshtein) → yellow, show correct answer, rate 3 (Hard).
       • No match → red, show correct answer, buttons "I had it" (rate 4) / "Got it wrong" (rate 0).
   - "Show answer" button to give up (rate 0).
   - Implement Levenshtein distance in lib/core/utils/string_utils.dart (~20 lines).

4. Progress bar and session stats (✓/✗ counts) must look consistent across all 3 modes.

Run flutter analyze — zero issues.
```

---

# PHASE 3 — Warstwa automatyzacji

> Faza 3 dodaje automatyzację na istniejący, działający rdzeń.
> Kolejność: tłumaczenie → wymowa → przykładowe zdania.

---

## ✅ Prompt 9 — Auto-tłumaczenie z Google ML Kit (DONE)

```
Add on-device translation to the Add Card screen using Google ML Kit.
No API keys — models are downloaded once (~30 MB each) and run offline.

1. Translation service — lib/services/translator_service.dart:
   Class TranslatorService:
   - Future<bool> isModelDownloaded(TranslateLanguage lang)
   - Future<void> downloadModel(TranslateLanguage lang, {bool requireWifi = true})
   - Future<String?> detectLanguage(String text)   -- LanguageIdentifier, threshold 0.5, null if uncertain
   - Future<String> translate(String text, TranslateLanguage from, TranslateLanguage to)
   - void dispose()
   Cache OnDeviceTranslator instances per language pair (expensive to create).
   Helper: TranslateLanguage fromCode(String code) maps 'pl'→TranslateLanguage.polish, etc.
   Expose as Riverpod provider (keepAlive: true).

2. Model download screen — lib/features/onboarding/model_download_screen.dart:
   Route: /onboarding/download (reached from Settings or first time after onboarding).
   - Two cards: source language + target language, each shows: name, "~30 MB", status chip.
   - Toggle "Download over Wi-Fi only" (default ON, read from connectivity_plus).
   - "Download" button → parallel download of both models.
   - Indeterminate progress (ML Kit doesn't expose download %).
   - After both done → "Continue" → back to wherever user came from.
   - "Skip" link → warning dialog → proceed anyway.

3. Add Card screen updates (extend Prompt 5):
   - After user types in source field (debounce 800ms):
       • Detect language.
       • If matches deck source OR target → translate to the other side.
       • Fill translation field (user can still edit it).
       • Show chip "Detected: Polish" below field.
       • Show "Translating…" indicator while in progress.
   - If model not downloaded → inline banner "Download [lang] model" → opens model download screen.
   - If translation fails → leave field empty, let user type manually.

4. Settings screen — add section "Language packs":
   - List downloaded models with delete button.
   - "Download models" button → /onboarding/download.

IMPORTANT: Verify current google_mlkit_translation API on pub.dev before writing code.
Run flutter analyze — zero issues.
```

---

## ✅ Prompt 10 — Wymowa (TTS) (DONE)

```
Add text-to-speech pronunciation for the target language.

1. TTS service — lib/services/tts_service.dart:
   Class TtsService:
   - Future<void> speak(String text, String languageCode)
       sets language, speech rate 0.5, volume 1.0, speaks.
   - Future<bool> isLanguageAvailable(String languageCode)
   - Future<void> stop()
   On unavailable language: SnackBar "Voice for [lang] not installed. Go to Android Settings → Accessibility → Text-to-speech."
   Expose as Riverpod provider (keepAlive: true).

2. Add speaker button to:
   - Flip Card back (after flip, next to target_text)
   - Card list rows in deck detail (small Icons.volume_up icon, trailing)
   - Add Card screen (next to translation field)

3. AndroidManifest.xml — add inside <manifest>:
   <queries>
     <intent>
       <action android:name="android.intent.action.TTS_SERVICE" />
     </intent>
   </queries>

4. First launch: if target language voice is not installed → one-time dialog explaining how to install.

Run flutter analyze — zero issues.
Note: emulator voice packs are limited — recommend testing on a real device.
```

---

## Krok pośredni przed Promptem 11 — Przetworzenie danych Tatoeba

Przed Promptem 11 musisz jednorazowo przetworzyć dane Tatoeba i wgrać je na GitHub Releases.

**Uruchom w osobnym folderze `tools/tatoeba/`:**

```
Create a Python script that pre-processes Tatoeba data into per-language-pair SQLite files.

Folder: tools/tatoeba/ (developer tool, not part of the Flutter app)
Python 3.10+, virtualenv + requirements.txt.

Steps:
1. Download from https://tatoeba.org/en/downloads:
   - sentences.tar.bz2 and links.tar.bz2
   - Cache locally, re-download if older than 30 days.

2. For each language pair generate a SQLite file:
   Schema:
     CREATE TABLE sentences (
       id INTEGER PRIMARY KEY,
       source_text TEXT NOT NULL,
       target_text TEXT NOT NULL,
       source_length INTEGER NOT NULL
     );
     CREATE VIRTUAL TABLE sentences_fts USING fts5(
       source_text, content='sentences', content_rowid='id',
       tokenize='unicode61 remove_diacritics 2'
     );
   Quality filters: length 15–80 chars, skip duplicates.
   Map Tatoeba 3-letter codes (eng, pol, deu…) to 2-letter ML Kit codes (en, pl, de…).

3. Compress each file to .zip (~3–5 MB).
   Output: tatoeba_pl_en.zip, tatoeba_en_pl.zip, etc.

4. Generate manifest.json:
   {
     "version": "2026-05-21",
     "license": "CC BY 2.0 — https://creativecommons.org/licenses/by/2.0/",
     "attribution": "Tatoeba.org contributors",
     "pairs": {
       "pl-en": { "url": "...", "size_bytes": ..., "sentence_count": ..., "checksum_sha256": "..." }
     }
   }

Usage: python preprocess.py --pairs pl-en,en-pl,en-de,de-en --output ./build

After running: upload .zip files + manifest.json to GitHub Releases.
Note the manifest URL — you'll need it in Prompt 11.
```

---

## Prompt 11 — Przykładowe zdania z Tatoeba

```
Implement example sentences using pre-processed Tatoeba data.

Manifest URL: [PASTE YOUR manifest.json URL FROM GITHUB RELEASES]

1. SentencesDatabase — lib/data/sentences/sentences_database.dart:
   One SQLite file per language pair, stored in app documents dir under sentences/.
   Methods:
   - Future<bool> isPairDownloaded(String source, String target)
   - Future<List<ExampleSentence>> findExamples(String word, String source, String target, {int limit = 5})
       Query: FTS5 MATCH on source_text, ORDER BY source_length ASC.
   - Future<void> deletePair(String source, String target)
   Use sqflite to open these files.

2. TatoebaDownloadService — lib/services/tatoeba_download_service.dart:
   - Future<Manifest> fetchManifest()  — GET manifest URL, cache 24h locally.
   - Future<void> downloadPair(String source, String target, {void Function(double)? onProgress}):
       dio download → verify SHA256 → unzip (archive package) → move .db → delete .zip.

3. Onboarding — add an optional step after language selection:
   Route /onboarding/sentences — "Download example sentences (optional)"
   Show pair info from manifest. Progress bar. Skip button.

4. Add Card screen — after translation:
   Query Tatoeba for the source word. Show up to 3 example sentences as tappable cards.
   Tap one → fills example_sentence + example_translation fields on the card.
   Add example_sentence and example_translation columns to the cards table (migration schemaVersion=2).
   "Skip example" and "Add custom" buttons.

5. Flip Card back — show example sentence (if present) in smaller text below target_text.

6. Settings screen — section "Sentence packs":
   Downloaded pairs with count, size, delete button. "Check for updates" and "Add pair" buttons.

7. About screen — "Example sentences from Tatoeba.org, CC BY 2.0."

Run flutter analyze — zero issues.
```

---

# PHASE 4 — Szlif i funkcje końcowe

---

## ✅ Prompt 12 — Powiadomienia i pełny ekran ustawień (DONE)

```
Add daily reminders and build the full Settings screen.

1. Notification service — lib/services/notification_service.dart:
   - Initialize flutter_local_notifications.
   - requestPermissions() — Android 13+ runtime permission.
   - scheduleDailyReminder({required TimeOfDay time, required String message})
       Use zonedSchedule + DateTimeComponents.time + local timezone (timezone package).
   - cancelAll()

2. AndroidManifest.xml — add permissions:
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
   <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   Declare the notification receiver per flutter_local_notifications README.

3. On notification tap → open app to Study tab.

4. Settings screen ('/settings') — full implementation:
   Section "Notifications":
     - Toggle "Daily reminder" (default OFF)
     - Time picker (default 19:00, disabled if toggle off)
     - Custom message field
   Section "Appearance":
     - Theme: System / Light / Dark (saves to shared_preferences, updates ThemeMode live)
   Section "Languages":
     - Native language (dropdown)
     - Default target language for new decks
   Section "Study":
     - Max new cards per day (number input, default 10)
   Section "Language packs" (from Prompt 9):
     - ML Kit models list with delete
   Section "Sentence packs" (from Prompt 11):
     - Tatoeba pairs list with delete
   Section "Data":
     - Import CSV (placeholder → Prompt 13)
     - Export CSV (placeholder → Prompt 13)

IMPORTANT: Verify flutter_local_notifications setup on pub.dev — Android 14+ has extra exact alarm requirements.
Run flutter analyze — zero issues.
```

---

## Prompt 13 — Import/eksport CSV

```
Add CSV import and export.

CSV format:
  source_text,target_text,notes
  "kot","cat",""
  "pies","dog","animal"
Header required. UTF-8 with BOM detection.

1. Export (lib/features/settings/export_service.dart):
   - Per-deck export: deck detail overflow menu → "Export to CSV"
   - All decks: Settings → "Export all decks" → ZIP of per-deck CSVs
   - Save to temp → share via share_plus.

2. Import (lib/features/settings/import_service.dart):
   - Settings → "Import CSV" → file_picker → pick .csv
   - Preview: first 5 rows, select target deck (existing or new), set source/target language.
   - Validate: wrong column count → show error with line number.
   - Bulk insert in batches of 100. Show progress.
   - New cards get default SM-2 values (next_review = now).

3. Edge cases:
   - Empty file, malformed rows, Unicode characters, files > 1000 rows.

4. "Sample CSV" button in Settings → exports a 3-row example file.

Test: export a deck → modify in a spreadsheet → import back → verify round-trip.
Run flutter analyze — zero issues.
```

---

## Prompt 14 — Wykończenie i szlif

```
Polish the app: error handling, accessibility, app icon, and about screen.

1. Error handling:
   - Global Riverpod error boundary for unexpected errors.
   - ML Kit not available → clear explanation screen.
   - Download failures → retry button + "App works offline" message.
   - Connectivity check (connectivity_plus): only show "offline" banner for actions that need internet (pack downloads).

2. All lists:
   - Skeleton loaders while loading async data.
   - Friendly empty states with icon and action button.

3. Confirmation dialogs:
   - Delete deck: "Delete '[name]' and all X cards? This cannot be undone."
   - Delete card: "Remove this card from the deck?"
   - Reset progress: confirm before clearing SM-2 data.

4. Accessibility:
   - Semantic labels on all icon buttons.
   - Min touch target 48×48 dp.
   - Support system text scaling.
   - Sufficient contrast in both themes (check with Flutter DevTools).

5. App icon + splash:
   - Add flutter_launcher_icons and flutter_native_splash to dev dependencies.
   - Configure a placeholder icon (letter "F" on teal background).
   - Run: dart run flutter_launcher_icons && dart run flutter_native_splash:create

6. About screen (/about):
   - App version (from package_info_plus).
   - "Translation powered by Google ML Kit (free, on-device)."
   - "Example sentences from Tatoeba.org (CC BY 2.0)."
   - Link to open-source licenses (showLicensePage).
   - Privacy policy note: "This app stores all data locally on your device. Nothing is sent to any server."

7. Final cleanup:
   - dart format . — format all files.
   - flutter analyze — zero issues, zero warnings.
   - flutter build apk --release — verify it builds.
   - Update README.md with setup instructions and Tatoeba attribution.
```

---

# Opcjonalne rozszerzenia

## Prompt 15 — BYOK: AI-generated examples (opcjonalny)

```
Add optional AI-generated example sentences where users bring their own API key.

Settings → new section "AI Examples":
- Toggle "Use AI for example sentences" (default OFF)
- Provider dropdown: Google Gemini (recommended, free tier) / OpenAI / Anthropic Claude
- Masked API key field + "Verify key" button
- Help text with links to get a free Gemini key

Security: store key in flutter_secure_storage, never log it.

Service (lib/services/ai_examples_service.dart):
- Abstract AiExamplesProvider with Gemini/OpenAI/Claude implementations.
- Future<ExampleSentence?> generate(String word, String targetLang, String nativeLang)
- Prompt: Generate ONE natural example sentence using "{word}" in {targetLang}.
           Return ONLY JSON: {"sentence": "...", "translation": "..."}
- Timeout 15s, one retry, handle 429 gracefully.

In Add Card flow (after Tatoeba results):
  1. Tatoeba results (always shown if available)
  2. "Generate with AI" button (only if enabled in settings)
  3. "Add custom"

AI-generated examples get a small "AI" badge.
Local usage counter: "AI examples generated today: X".

Clear messaging in Settings: "This app is free and offline-first. AI examples are optional and use YOUR key."
```

---

## Prompt 16 — Cloud sync z Supabase (PostgreSQL)

```
Add optional cloud sync using Supabase (PostgreSQL backend).
Architecture: local SQLite remains the primary store — app works fully offline.
Sync is opt-in: user creates an account or skips it entirely.

Design goal: the sync layer must be swappable — we'll migrate from Supabase to
Azure PostgreSQL later, so keep all backend calls behind an abstract SyncBackend
interface.

---

### 1. Dependencies to add to pubspec.yaml
   - supabase_flutter (latest stable)
   - connectivity_plus (already present)

---

### 2. Abstract sync interface — lib/services/sync/sync_backend.dart

abstract class SyncBackend {
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Stream<bool> get authStateChanges;   // true = signed in
  String? get currentUserId;

  Future<void> pushDecks(List<Deck> decks);
  Future<void> pushCards(List<FlashCard> cards);
  Future<void> pushReviewLogs(List<ReviewLog> logs);
  Future<void> pushUserStats(UserStat stats);

  Future<List<Map<String, dynamic>>> pullDecks(DateTime? since);
  Future<List<Map<String, dynamic>>> pullCards(DateTime? since);
  Future<List<Map<String, dynamic>>> pullReviewLogs(DateTime? since);
  Future<Map<String, dynamic>?> pullUserStats();
}

---

### 3. Supabase implementation — lib/services/sync/supabase_backend.dart

class SupabaseBackend implements SyncBackend {
  // Uses supabase_flutter client.
  // Tables mirror the local drift schema (same column names).
  // Every row has: user_id (UUID FK to auth.users), updated_at (timestamptz).
  // Row-level security: user can only read/write their own rows.
  // All push methods use upsert (insert or update by primary key + user_id).
  // All pull methods filter by user_id and updated_at > since.
}

Expose as Riverpod provider:
  final syncBackendProvider = Provider<SyncBackend>((ref) => SupabaseBackend());

---

### 4. Supabase project setup (document in README, not code)
   SQL to run in Supabase SQL editor:

   -- Enable RLS and create tables matching local schema
   create table decks (
     id uuid primary key default gen_random_uuid(),
     local_id int not null,
     user_id uuid references auth.users not null,
     name text not null,
     description text,
     source_language text not null,
     target_language text not null,
     created_at timestamptz not null,
     updated_at timestamptz not null
   );
   alter table decks enable row level security;
   create policy "own rows" on decks for all using (auth.uid() = user_id);

   -- Repeat for cards, review_logs, user_stats (same structure pattern)
   -- cards has all SM-2 columns
   -- review_logs has card local_id reference
   -- user_stats is a single row per user

---

### 5. Sync service — lib/services/sync/sync_service.dart

class SyncService {
  SyncService(this._backend, this._db);
  final SyncBackend _backend;
  final AppDatabase _db;

  // Last sync timestamp stored in SharedPreferences key 'last_sync_at'
  Future<void> syncAll() async {
    // 1. Push local changes (created/updated since last sync)
    // 2. Pull remote changes (updated_at > last_sync_at)
    // 3. Merge: remote wins for same updated_at tie-break
    // 4. Update 'last_sync_at' = now
  }

  Future<void> fullPush() async { /* push everything, ignore timestamps */ }
  Future<void> fullPull() async { /* pull everything, replace local */ }
}

Expose as Riverpod provider.

---

### 6. Auth screens — lib/features/auth/

LoginScreen:
  - Email + password fields
  - "Sign In" and "Sign Up" buttons
  - "Continue without account" → closes
  - Show loading indicator during auth

Route: /auth/login

---

### 7. Settings screen — add "Account" section

Section "Account" (top of settings):
  - If signed out: "Sign in to sync your data" → /auth/login
  - If signed in: show email, "Sync now" button, "Last synced: X min ago", "Sign out"
  
"Sync now":
  - Checks connectivity first
  - Calls SyncService.syncAll()
  - Shows result: "Synced X decks, Y cards" or error

Auto-sync: trigger SyncService.syncAll() on app start if signed in + online.

---

### 8. Migration path to Azure PostgreSQL (document in README)

To switch from Supabase to Azure PostgreSQL later:
1. Create a new class AzurePostgresBackend implements SyncBackend
2. Use the `postgres` Dart package (or a REST API wrapper)
3. Change: final syncBackendProvider = Provider<SyncBackend>((ref) => AzurePostgresBackend(...))
4. The rest of the app is untouched — SyncService, UI, and data model stay identical

The abstract interface is intentionally narrow so the swap is a single-file change.

---

IMPORTANT:
- The app must work fully offline if the user has no account or no internet.
- Sync errors must never crash the app — show a non-blocking snackbar.
- Never sync automatically on mobile data without user permission.
- Supabase URL and anon key go in a .env file (use flutter_dotenv or hardcode in
  a gitignored lib/core/config/supabase_config.dart — DO NOT commit keys).
- Run flutter analyze — zero issues.
```

---

## Prompt 17 — iOS przez Codemagic (po MVP)

> Previously Prompt 16 — renumbered after adding cloud sync.

```
The Android version is working. Prepare the app for iOS build via Codemagic.

1. Run: flutter create --platforms=ios .
2. ios/Runner/Info.plist: add NSMicrophoneUsageDescription (for future speech feature).
3. Set minimum iOS 15.5 in ios/Podfile and Runner.xcodeproj (required by ML Kit).
4. ios/Podfile: exclude armv7, add ML Kit post_install hook per google_mlkit_translation README.
5. flutter_local_notifications: configure DarwinInitializationSettings.
6. flutter_tts: verify iOS configuration in README.
7. Create codemagic.yaml at project root:
   - Workflow: iOS unsigned build (for testing)
   - Workflow: iOS App Store build (code signing via Codemagic)
8. Document Codemagic setup steps in README.

I don't have a Mac — the entire iOS toolchain runs through Codemagic CI.
```

---

## Model biznesowy (przemyśl od początku)

**Opcja D: BYOK + free (polecana dla pierwszej aplikacji)**
- Aplikacja całkowicie darmowa
- Power users dodają własny klucz AI dla lepszych funkcji (Prompt 15)
- Zero kosztów operacyjnych dla Ciebie
- Koszty: Google Play $25 jednorazowo · Apple Developer $99/rok · Hosting Tatoeba $0 (GitHub Releases)

---

## Częste problemy i rozwiązania

**drift_dev nie generuje plików:**
→ `dart run build_runner build --delete-conflicting-outputs`

**Notyfikacje nie działają na Androidzie 14:**
→ Sprawdź `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` permissions.

**flutter_tts mówi tylko po angielsku:**
→ Emulator nie ma voice packów. Test na prawdziwym urządzeniu.

**ML Kit: "model not downloaded" mimo pobierania:**
→ Model jest per device/emulator. Po reinstalacji trzeba pobrać ponownie. Zawsze sprawdzaj `isModelDownloaded` przed `translate`.

**Tatoeba nie ściąga:**
→ Sprawdź czy GitHub Release jest publiczny, sprawdź URL w manifest.json, sprawdź INTERNET permission w AndroidManifest.

**APK waży 50+ MB:**
→ Użyj App Bundle: `flutter build appbundle` — Google Play serwuje mniejsze paczki per urządzenie.
