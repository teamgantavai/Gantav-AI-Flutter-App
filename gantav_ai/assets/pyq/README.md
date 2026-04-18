# PYQ Datasets

Bundled past-year-question banks. Loaded with priority over AI generation.

## File naming

`{exam_id}_{subject_id}.json` — e.g. `entrance_physics.json`, `ssc_reasoning.json`.

Must match `ExamCategory.id` and `ExamSubject.id` from `lib/models/exam_models.dart`
(`ssc_reasoning`, `upsc_polity`, `bank_quant`, `entrance_physics`, etc.).

## Schema

Flat JSON array of `ExamQuestion` records:

```json
[
  {
    "id": "jee_phy_2023_001",
    "question": "A ball is thrown vertically upward with velocity 20 m/s ...",
    "options": ["1s", "2s", "3s", "4s"],
    "correct_index": 1,
    "explanation": "Using v = u - gt, at max height v = 0 ...",
    "topic": "Mechanics · Kinematics · 2023",
    "marks": 4.0,
    "negative_marks": 1.0
  }
]
```

Field rules:
- `id` **must** be unique across the whole file (used as Firestore doc id)
- `options` **must** have exactly 4 entries
- `correct_index` is 0-indexed (0 = first option)
- `topic` is free-form — include the year here so it surfaces in the UI
- `marks` / `negative_marks` follow the exam's marking scheme (JEE Mains: +4 / -1)

## Drop-in workflow for GitHub datasets

1. Download the source JSON (e.g. the 14k-question JEE Mains PYQ GitHub repo).
2. Normalise each record into the schema above. Field mappings that typically
   need renaming:
   - `answer` / `correct` / `correctAnswer` → `correct_index` (convert letter
     "A/B/C/D" to 0/1/2/3)
   - `question_text` / `text` → `question`
   - `subject` → part of `topic`, plus use it to pick the target file
3. Save as `assets/pyq/{exam_id}_{subject_id}.json`.
4. Rebuild (`flutter run`) — the bank auto-loads on next mock test.
5. (Optional) In the app: Profile → Admin → **Import PYQ Bank** to mirror the
   bundled asset into Firestore so other users/devices share the same bank.

## Why bundled + Firestore?

- **Bundled asset** → works offline on first install, ships with every build.
- **Firestore mirror** → admin can top up / swap datasets remotely without
  shipping a new APK. `ExamService` checks Firestore after asset, so remote
  overrides win when present.
