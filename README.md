# Activity 09 Card Catalogue
Darsh Rathi — CSC 4360 undergraduate, MW section.

Folders contain cards. The Part I guest roster is still available using the people button.

## Run
Flutter 3.48.0-0.5.pre / Dart 3.14.0 beta; Android 16 API 36 emulator.
```sh
flutter pub get
flutter run -d emulator-5554
flutter analyze
flutter build apk --release
```
The three instructor dependency constraints were retained: sqflite ^2.4.1,
path_provider ^2.1.5, path ^1.9.0. pubspec.lock records resolved versions.
The generated project SDK constraint was retained for the installed Flutter SDK.

## Database
The instructor's instance-based helper opens app_flutter/MyDatabase.db.
Version 1's my_table (_id, name, age) is unchanged. Version 2 adds folders,
cards, and idx_cards_folder_id. onConfigure enables foreign keys; onUpgrade
adds the catalogue inside sqflite's existing callback transaction. onCreate
creates both the original and catalogue schemas. There is no automatic seeding.

The Part I baseline was created on October 13 for this assignment, not during an
earlier class session. Before upgrading, River ID 1 age 21 and River ID 2 age 34
were saved through the roster UI and backed up. Both IDs/names/ages remained
unchanged after upgrading and after T4.

Folder.toMap/fromMap and CardRecord.toMap/fromMap are in lib/models.dart.
SQL and all CRUD are in lib/database_helper.dart; UI is in lib/main.dart and
lib/catalogue.dart. Values are bound, and writes target IDs. Empty folders remain
visible with zero counts. Names are trimmed and unique with SQLite's default
case-sensitive comparison. Card titles may repeat.

ON DELETE CASCADE removes a folder's cards. Restrict or archival would be safer
when child records must be retained, such as billing/audit records.
image_ref is nullable. This build uses null references and suit placeholders;
optional bundled asset paths use Image.asset with an error fallback. References
never store the image bytes. No image assets are bundled; adding a valid asset
requires declaring it in pubspec.yaml. URLs/private files are not loaded and also
show the placeholder. This keeps the required flow offline with no extra packages.

## Tests on emulator-5554
These are device UI interactions and read-only copies of the app database,
not an automated Flutter test suite. All data is fictional. Insert IDs came from
the real database; save/delete feedback reports returned IDs/affected rows.

| Test/action | Expected | Observed | Result |
| --- | --- | --- | --- |
| T1a upgrade 1 to 2 | Old rows preserved; tables/index/FK added | River IDs 1/2 ages 21/34 unchanged; version 2; active connection foreign_keys=1; cards FK targets folders.id with CASCADE; idx_cards_folder_id present | Pass |
| T1b separate fresh package | Original and catalogue tables exist; empty folder opens | com.darshrathi.local_storage_lab.fresh had version 2, zero guests/cards; Fresh check opened empty; FK=1 and index present | Pass |
| T2 create Atlas/Harbor and three cards | Distinct card IDs; counts 2/1; folder filtering | Atlas ID 1, Harbor ID 2; Compass IDs 1/2 in Atlas; Signal ID 3 in Harbor; all Hearts; Signal notes Harbor notes and image_ref NULL; counts 2/1 | Pass |
| T3 edit one Compass; cancel another | Exactly one row updated; cancel writes nothing | ID 1 became Compass revised with Corrected route; saved feedback 1 row; ID 2 remained Compass with empty notes; counts 2/1 | Pass |
| T4 force-stop/relaunch | Identical IDs/values/counts, no seeds | Before/after full database snapshots matched: both guests, both folders, cards 1/2/3, notes, NULL images, and counts 2/1 | Pass |
| T5 card cancel/delete; folder cancel/delete | Cancel changes nothing; cascade only Atlas | Both cancels left snapshots unchanged; deleted card 1: 1 row, Atlas count 1; deleted Atlas: 1 parent row and card 2 removed; Harbor/Signal 3 remained; no Atlas references | Pass |
| T6 null image, whitespace title/name, duplicate Harbor | Placeholder/feedback; no invalid writes | Hearts fallback visible for Signal; blank title/name rejected; duplicate Harbor rejected with input retained; records/counts unchanged | Pass |

T4 procedure: stopped the app with Android am force-stop, then launched the same
package/component. No storage clear, uninstall, hot reload, or hot restart was used.
Pre-T4 values: guest 1 River/21 and guest 2 River/34; Atlas 1 and Harbor 2;
card 1 Compass revised/Corrected route/Hearts/folder 1; card 2
Compass/empty notes/Hearts/folder 1; card 3 Signal/Harbor notes/Hearts/folder 2.
All image_ref values were NULL. The post-restart records were identical.

Evidence: evidence/T1_before.png, T2_cards.png, T4_after.png,
T6_fallback.png, T6_invalid.png, and analysis_output.txt. Analyzer: no issues.

## Release
Built with flutter build apk --release. Activity09_Rathi_Darsh.apk was installed
on emulator-5554 without clearing the guest database. UI smoke checks verified
folder/card create/read, edit, confirmed card/folder deletion, image fallback,
and force-stop/relaunch persistence. Temporary release test records were removed
through the UI; the two guests and Harbor/Signal remained unchanged.

## Rubric map
Schema/preservation (25): database_helper.dart, T1a/T1b/T5, T1_before.png.
Models/CRUD (25): models.dart and helper; catalogue.dart; T2/T3/T5/T6.
Image/usability (10): CardArtwork, list/form states, T6.
Testing/evidence (20): table/screenshots/analyzer and release smoke test.
Reflection (15): separate Rathi_Darsh_CriticalThinking.docx, prompts 1–3 + U1/U4.
Delivery (5): source/platform/dependencies, README, github_link.txt, tested APK/DOCX.
The user handles iCollege uploads and receipt verification; these are not claimed complete.

## References and assistance
Instructor Activity 08 helper and YAML: https://codd.cs.gsu.edu/~lhenry23/mad/ica/act08/index2.html
Activity 09 instructions: https://codd.cs.gsu.edu/~lhenry23/mad/ica/act09/v2/index2.html
Class SQLite lecture and supplied slides informed the models/helper approach.
Codex assisted with implementation, device checks, and writing on October 13, 2026.
Exact model identifier was not exposed. The reflection includes the disclosure.

## Limits
This Android project uses the installed beta Flutter SDK and its generated SDK
constraint. The original Part I baseline was established during this work.
No forced read-error/network fault or spoken screen-reader session was run.
Only null fallback was exercised by the required T6; invalid/missing asset fallback
is implemented using Image.asset's errorBuilder. Upload completion depends on the user.
