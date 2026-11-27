# `00_candidates.json` schema

```json
{
 "tracks": {
  "C": "[Novelty] 제안 방법이 새로 보여 주는 것",
  "B": "[한계] 기존 방법의 한계",
  "A": "[선행 연구] 기존 방법"
 },
 "papers": [ { ...entry... }, ... ]
}
```

Other top-level keys (search logs, round records) are allowed; the script reads only `tracks` and `papers`. Write the file as UTF-8 with `ensure_ascii=False` so Korean stays readable.

## `tracks`

An ordered object: key → group label (a research claim in the default).

- Order is priority. A paper's canvas group is the first key in `tracks` that the paper carries, so list first the group that should hold a paper carrying several keys (in the default, the claim closest to the user's novelty).
- Keys are short (one letter is easiest to type in `tracks` arrays). The Base gets one card view per key, named `트랙 <key>: <text>`.
- The canvas group label is `<key> · <text>`. After changing the text, rename the group label on the canvas to the same string; otherwise the next new card of that track creates a second group. The Base view name is changed by hand in `00_Database.base`.

## Entry fields

| Key | Required | Rule |
|---|---|---|
| `id` | yes | `P` + three digits, unique, never reused or changed |
| `title` | yes | Original title, verbatim |
| `year` | yes | Number, no quotes |
| `venue_abbrev` | yes | Short venue: `ICRA`, `IROS`, `IEEE Robot. Autom. Lett.`, `arXiv` |
| `tracks` | yes | Non-empty array of keys from `tracks` |
| `filename` | yes | Unique; see the filename rule below |
| `status` | yes | `대기` or `접근 불가` (with a reason in `status_note`). When the PDF is in `pdf/`, the note gets `다운로드 완료` regardless |
| `authors` | no | Surnames, comma-separated: `Chen, Khamis, Lepora` |
| `doi` | no | `10.xxxx/...` or `""`; becomes the note's DOI link |
| `landing_url` | no | Paper page; used for the link when there is no DOI |
| `tier` | no | `1` must read, `2` recommended, `3` optional |
| `reason` | no | One or two sentences: why the paper is in the DB (in the default, which track claim it backs and how) |
| `key_numbers` | no | The numbers that matter for the DB's purpose (latency, rate, accuracy…) or "none" |
| `numbers_source` | no | `abstract`, `full text`, `secondary source`, `none seen` |
| `related` | no | Array of `id`s; each pair gets one canvas edge and a `related` property link |
| anything else | no | Kept for the record (`venue_full`, `pub_type`, `access`, `note`, `status_note`, …); not read |

Fill `reason` and `key_numbers` from what was actually read. Mark the source honestly in `numbers_source`; a number taken from an abstract or a citing paper is weaker evidence than one from the full text.

## Filename rule

`<year>_<venue letters and digits>_<title>.pdf`

- Venue: keep only ASCII letters and digits: `IEEE Robot. Autom. Lett.` → `IEEERobotAutomLett`.
- Title: delete `\ / : * ? " < > |` and `# ^ [ ]` (wikilinks to names containing them do not resolve); replace `—` and `–` with `-`.
- Cut the end of the title so the whole name stays under ~150 characters. Every note and image name is `DB_` + this name + a suffix, and the longest one must fit the Windows 259-character path limit together with the vault folder path.
- Example: `2023_ICRA_Design of a Multimodal Fingertip Sensor for Dynamic Manipulation.pdf`

Python sketch:

```python
import re
def make_filename(year, venue, title, limit=150):
    v = re.sub(r"[^A-Za-z0-9]", "", venue)
    t = re.sub(r'[\\/:*?"<>|#^\[\]]', "", title.replace("—", "-").replace("–", "-")).strip()
    head = f"{year}_{v}_"
    return head + t[: limit - len(head) - 4].rstrip() + ".pdf"
```

## Entry template

```json
{
  "id": "P013",
  "title": "논문 원제목",
  "authors": "Last1, Last2, Last3",
  "year": 2026,
  "venue_abbrev": "ICRA",
  "doi": "10.1109/...",
  "landing_url": "https://doi.org/10.1109/...",
  "tracks": ["A", "C"],
  "tier": 2,
  "reason": "이 논문이 어떤 트랙 주장을 뒷받침하는지 한두 문장",
  "key_numbers": "응답 속도, 지연, 정확도 같은 수치",
  "numbers_source": "abstract",
  "related": ["P004"],
  "filename": "2026_ICRA_논문 원제목.pdf",
  "status": "대기",
  "status_note": ""
}
```

## Deduplication

Before adding an entry, compare against existing entries:

1. Same DOI (case-insensitive) → duplicate.
2. Titles equal after lowercasing and removing non-alphanumerics → duplicate (catches the same paper with and without a DOI).
3. Preprint vs published version of the same work → keep the published one; put the arXiv id in `note` if useful.

For dropped PDFs, also compare file hashes (`hashlib.sha256`) against `pdf/`; identical bytes under another name are a duplicate.
