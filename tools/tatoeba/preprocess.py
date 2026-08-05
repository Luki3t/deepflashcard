#!/usr/bin/env python3
"""
Tatoeba preprocessor — builds per-language-pair SQLite + FTS5 databases.

Downloads sentence data from tatoeba.org, filters and pairs them, then
produces one .zip per language pair ready to upload to GitHub Releases.

Usage:
    python preprocess.py --pairs pl-en,en-pl,de-en,en-de --output ./build
"""

import argparse
import csv
import hashlib
import io
import json
import sqlite3
import sys
import tarfile
import zipfile
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

import requests
from tqdm import tqdm

# ── Config ────────────────────────────────────────────────────────────────────

SENTENCES_URL = "https://downloads.tatoeba.org/exports/sentences.tar.bz2"
LINKS_URL     = "https://downloads.tatoeba.org/exports/links.tar.bz2"
CACHE_DIR     = Path(".cache")
CACHE_MAX_AGE = timedelta(days=30)

MIN_LEN = 15
MAX_LEN = 80

# Tatoeba 3-letter ISO 639-3 → ML Kit 2-letter codes
LANG_MAP = {
    "eng": "en", "pol": "pl", "deu": "de", "spa": "es",
    "fra": "fr", "ita": "it", "por": "pt", "rus": "ru",
    "ukr": "uk", "cmn": "zh", "jpn": "ja", "kor": "ko",
    "nld": "nl", "swe": "sv", "nob": "no", "nno": "no",
    "ces": "cs", "slk": "sk", "hun": "hu", "tur": "tr",
}

REVERSE_MAP: dict[str, list[str]] = defaultdict(list)
for _t, _m in LANG_MAP.items():
    REVERSE_MAP[_m].append(_t)

# ── Download helpers ──────────────────────────────────────────────────────────

def _needs_download(path: Path) -> bool:
    if not path.exists():
        return True
    age = datetime.now() - datetime.fromtimestamp(path.stat().st_mtime)
    return age > CACHE_MAX_AGE


def download(url: str, dest: Path) -> None:
    print(f"Downloading {url}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    r = requests.get(url, stream=True, timeout=120)
    r.raise_for_status()
    total = int(r.headers.get("content-length", 0))
    with open(dest, "wb") as f, tqdm(total=total, unit="B", unit_scale=True) as bar:
        for chunk in r.iter_content(chunk_size=1 << 20):
            f.write(chunk)
            bar.update(len(chunk))


def ensure_cached(url: str, name: str) -> Path:
    path = CACHE_DIR / name
    if _needs_download(path):
        download(url, path)
    else:
        print(f"Using cached {path}")
    return path


# ── Data loading ──────────────────────────────────────────────────────────────

def load_sentences(path: Path, needed_ml: set[str]) -> dict[int, tuple[str, str]]:
    """Returns {sentence_id: (ml_lang_code, text)} for the needed languages only."""
    needed_tatoeba = {t for m in needed_ml for t in REVERSE_MAP[m]}
    print(f"Loading sentences for Tatoeba codes: {sorted(needed_tatoeba)}")
    result: dict[int, tuple[str, str]] = {}
    with tarfile.open(path, "r:bz2") as tar:
        member = next(m for m in tar.getmembers() if m.name.endswith(".csv"))
        f = tar.extractfile(member)
        assert f is not None
        reader = csv.reader(io.TextIOWrapper(f, encoding="utf-8"), delimiter="\t")
        for row in tqdm(reader, desc="Sentences", unit=" rows"):
            if len(row) < 3:
                continue
            sid, lang, text = int(row[0]), row[1], row[2]
            ml = LANG_MAP.get(lang)
            if ml and ml in needed_ml:
                result[sid] = (ml, text)
    print(f"  Loaded {len(result):,} sentences")
    return result


def load_links(path: Path, sentence_ids: set[int]) -> dict[int, list[int]]:
    """Returns {sentence_id: [translation_ids]} only for IDs we care about."""
    print("Loading links…")
    result: dict[int, list[int]] = defaultdict(list)
    with tarfile.open(path, "r:bz2") as tar:
        member = next(m for m in tar.getmembers() if m.name.endswith(".csv"))
        f = tar.extractfile(member)
        assert f is not None
        reader = csv.reader(io.TextIOWrapper(f, encoding="utf-8"), delimiter="\t")
        for row in tqdm(reader, desc="Links", unit=" rows"):
            if len(row) < 2:
                continue
            a, b = int(row[0]), int(row[1])
            if a in sentence_ids:
                result[a].append(b)
    return result


# ── SQLite builder ────────────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE sentences (
    id            INTEGER PRIMARY KEY,
    source_text   TEXT    NOT NULL,
    target_text   TEXT    NOT NULL,
    source_length INTEGER NOT NULL
);
CREATE VIRTUAL TABLE sentences_fts USING fts5(
    source_text,
    content='sentences',
    content_rowid='id',
    tokenize='unicode61 remove_diacritics 2'
);
"""


def build_pair(src: str, tgt: str, key: str,
               sentences: dict[int, tuple[str, str]],
               links: dict[int, list[int]],
               output_dir: Path) -> dict:
    db_path  = output_dir / f"tatoeba_{key}.db"
    zip_path = output_dir / f"tatoeba_{key}.zip"

    print(f"\nBuilding {key}…")
    if db_path.exists():
        db_path.unlink()

    con = sqlite3.connect(db_path)
    con.executescript(SCHEMA)

    seen_sources: set[str] = set()
    rows = []

    for sid, (ml_lang, src_text) in sentences.items():
        if ml_lang != src:
            continue
        if not (MIN_LEN <= len(src_text) <= MAX_LEN):
            continue
        if src_text in seen_sources:
            continue
        for tid in links.get(sid, []):
            if tid not in sentences:
                continue
            tgt_lang, tgt_text = sentences[tid]
            if tgt_lang != tgt:
                continue
            rows.append((sid, src_text, tgt_text, len(src_text)))
            seen_sources.add(src_text)
            break  # one translation per source sentence

    con.executemany(
        "INSERT INTO sentences(id, source_text, target_text, source_length) VALUES (?,?,?,?)",
        rows,
    )
    con.execute("INSERT INTO sentences_fts(sentences_fts) VALUES('rebuild')")
    con.commit()
    con.close()

    print(f"  {len(rows):,} sentence pairs → compressing…")

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(db_path, f"tatoeba_{key}.db")
    db_path.unlink()

    size = zip_path.stat().st_size
    sha  = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    print(f"  {zip_path.name}  {size / 1e6:.1f} MB  sha256={sha[:16]}…")

    return {
        "url": f"__GITHUB_RELEASE_BASE_URL__/tatoeba_{key}.zip",
        "size_bytes": size,
        "sentence_count": len(rows),
        "checksum_sha256": sha,
    }


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Preprocess Tatoeba data for the Flashcards app"
    )
    parser.add_argument(
        "--pairs", required=True,
        help="Comma-separated language pairs, e.g. pl-en,en-pl,de-en,en-de",
    )
    parser.add_argument(
        "--output", default="./build",
        help="Output directory for .zip files and manifest.json (default: ./build)",
    )
    args = parser.parse_args()

    pair_keys = [p.strip() for p in args.pairs.split(",")]
    pairs: list[tuple[str, str, str]] = []
    for key in pair_keys:
        parts = key.split("-")
        if len(parts) != 2:
            print(f"ERROR: invalid pair '{key}' — expected format 'src-tgt'", file=sys.stderr)
            sys.exit(1)
        src, tgt = parts
        if src not in REVERSE_MAP:
            print(f"ERROR: unsupported source language '{src}'", file=sys.stderr)
            sys.exit(1)
        if tgt not in REVERSE_MAP:
            print(f"ERROR: unsupported target language '{tgt}'", file=sys.stderr)
            sys.exit(1)
        pairs.append((src, tgt, key))

    needed_ml = {lang for src, tgt, _ in pairs for lang in (src, tgt)}

    sentences_cache = ensure_cached(SENTENCES_URL, "sentences.tar.bz2")
    links_cache     = ensure_cached(LINKS_URL,     "links.tar.bz2")

    sentences   = load_sentences(sentences_cache, needed_ml)
    sentence_ids = set(sentences.keys())
    links       = load_links(links_cache, sentence_ids)

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest_pairs: dict[str, dict] = {}
    for src, tgt, key in pairs:
        manifest_pairs[key] = build_pair(src, tgt, key, sentences, links, output_dir)

    manifest = {
        "version": datetime.now().strftime("%Y-%m-%d"),
        "license": "CC BY 2.0 — https://creativecommons.org/licenses/by/2.0/",
        "attribution": "Tatoeba.org contributors",
        "pairs": manifest_pairs,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))

    print("\n" + "=" * 60)
    print("Done! Next steps:")
    print("  1. Upload all .zip files from", output_dir, "to a GitHub Release")
    print("  2. Edit manifest.json — replace __GITHUB_RELEASE_BASE_URL__")
    print("     with the actual base URL of your GitHub Release assets")
    print("     e.g. https://github.com/YOU/REPO/releases/download/tatoeba-v1")
    print("  3. Upload the updated manifest.json to the same GitHub Release")
    print("  4. Copy the raw URL of manifest.json — you'll need it in Prompt 11")
    print("=" * 60)


if __name__ == "__main__":
    main()
