#!/usr/bin/env python3
"""Review local Kaggle Book Recommendation Dataset CSVs for augmentation use.

This script does not download Kaggle data and does not train a model. It checks
whether local `Books.csv`, `Ratings.csv`, and optionally `Users.csv` are suitable
as auxiliary pretraining data for Commendo's recommendation ranker.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

BOOK_REQUIRED_COLUMNS = {"ISBN", "Book-Title", "Book-Author", "Year-Of-Publication", "Publisher"}
RATING_REQUIRED_COLUMNS = {"User-ID", "ISBN", "Book-Rating"}
USER_REQUIRED_COLUMNS = {"User-ID", "Location", "Age"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--books", help="Path to Kaggle Books.csv.")
    parser.add_argument("--ratings", help="Path to Kaggle Ratings.csv.")
    parser.add_argument("--users", help="Optional path to Kaggle Users.csv.")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--max-ratings", type=int, default=0, help="Optional cap for quick local checks.")
    parser.add_argument("--demo-data", action="store_true", help="Use deterministic fixture data.")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if args.demo_data:
        books, ratings, users = demo_data()
        paths = {"books": "demo", "ratings": "demo", "users": "demo"}
    else:
        if not args.books or not args.ratings:
            raise SystemExit("--books and --ratings are required unless --demo-data is set.")
        books = read_csv_rows(Path(args.books))
        ratings = read_csv_rows(Path(args.ratings), max_rows=args.max_ratings)
        users = read_csv_rows(Path(args.users)) if args.users else []
        paths = {"books": args.books, "ratings": args.ratings, "users": args.users}

    report = build_report(books=books, ratings=ratings, users=users, paths=paths)
    report_path = output_dir / "kaggle_review_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"report: {report_path}")
    print(f"decision: {report['recommendation']['decision']}")
    return 0


def build_report(
    books: list[dict[str, str]],
    ratings: list[dict[str, str]],
    users: list[dict[str, str]],
    paths: dict[str, str | None],
) -> dict[str, Any]:
    book_columns = set(books[0]) if books else set()
    rating_columns = set(ratings[0]) if ratings else set()
    user_columns = set(users[0]) if users else set()
    book_by_isbn = build_book_index(books)
    rating_stats = analyze_ratings(ratings=ratings, book_by_isbn=book_by_isbn)
    pair_stats = estimate_pair_counts(ratings)
    bias_stats = analyze_bias(books=books, users=users)
    schema = {
        "books": schema_status(book_columns, BOOK_REQUIRED_COLUMNS),
        "ratings": schema_status(rating_columns, RATING_REQUIRED_COLUMNS),
        "users": schema_status(user_columns, USER_REQUIRED_COLUMNS) if users else {"status": "not_provided"},
    }

    decision = review_decision(schema=schema, rating_stats=rating_stats, pair_stats=pair_stats)
    return {
        "paths": paths,
        "schema": schema,
        "counts": {
            "books": len(books),
            "ratings": len(ratings),
            "users": len(users),
        },
        "isbn": {
            "books_normalized_isbn13": len(book_by_isbn),
            "book_isbn_normalization_rate": ratio(len(book_by_isbn), len(books)),
            "rating_isbn_match_rate": rating_stats["isbn_match_rate"],
        },
        "ratings": rating_stats,
        "pair_estimates": pair_stats,
        "bias": bias_stats,
        "augmentation_policy": {
            "role": "auxiliary_pretraining_only",
            "default_sample_weight": 0.35,
            "positive_rule": "same user high-rated book pairs, Book-Rating >= 8",
            "negative_rule": "same user high-rated seed paired with low-rated book, 1 <= Book-Rating <= 4",
            "exclude": [
                "implicit zero ratings for positive labels",
                "rows with ISBNs that cannot normalize to ISBN-13",
                "rows whose ISBNs do not exist in Books.csv",
            ],
            "acceptance": "Do not accept a mixed model unless it improves the Data4Library test split.",
        },
        "recommendation": {
            "decision": decision,
            "notes": recommendation_notes(decision, schema, rating_stats, pair_stats),
        },
    }


def schema_status(columns: set[str], required: set[str]) -> dict[str, Any]:
    missing = sorted(required - columns)
    return {
        "status": "ok" if not missing else "missing_columns",
        "missing": missing,
        "columns": sorted(columns),
    }


def build_book_index(books: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    book_by_isbn = {}
    for book in books:
        isbn13 = normalize_isbn13(book.get("ISBN", ""))
        if isbn13:
            book_by_isbn[isbn13] = book
    return book_by_isbn


def analyze_ratings(
    ratings: list[dict[str, str]],
    book_by_isbn: dict[str, dict[str, str]],
) -> dict[str, Any]:
    counts = Counter()
    normalized = 0
    matched = 0
    explicit_values = []
    high_by_user: dict[str, int] = defaultdict(int)
    low_by_user: dict[str, int] = defaultdict(int)

    for row in ratings:
        rating = parse_int(row.get("Book-Rating", ""))
        isbn13 = normalize_isbn13(row.get("ISBN", ""))
        if isbn13:
            normalized += 1
        if isbn13 in book_by_isbn:
            matched += 1

        if rating == 0:
            counts["implicit_zero"] += 1
        elif rating is None:
            counts["invalid"] += 1
        else:
            explicit_values.append(rating)
            if rating >= 8:
                counts["high_8_to_10"] += 1
                high_by_user[row.get("User-ID", "")] += 1
            elif rating <= 4:
                counts["low_1_to_4"] += 1
                low_by_user[row.get("User-ID", "")] += 1
            else:
                counts["mid_5_to_7"] += 1

    return {
        "bucket_counts": dict(sorted(counts.items())),
        "explicit_rating_count": len(explicit_values),
        "explicit_rating_average": mean(explicit_values),
        "isbn_normalization_rate": ratio(normalized, len(ratings)),
        "isbn_match_rate": ratio(matched, len(ratings)),
        "users_with_two_or_more_high_ratings": sum(1 for value in high_by_user.values() if value >= 2),
        "users_with_high_and_low_ratings": sum(
            1 for user, high_count in high_by_user.items()
            if high_count > 0 and low_by_user.get(user, 0) > 0
        ),
    }


def estimate_pair_counts(ratings: list[dict[str, str]]) -> dict[str, int]:
    high_by_user: dict[str, int] = defaultdict(int)
    low_by_user: dict[str, int] = defaultdict(int)
    for row in ratings:
        rating = parse_int(row.get("Book-Rating", ""))
        user = row.get("User-ID", "")
        if not user or rating is None:
            continue
        if rating >= 8:
            high_by_user[user] += 1
        elif 1 <= rating <= 4:
            low_by_user[user] += 1

    positive_pairs = sum(combinations_2(count) for count in high_by_user.values())
    negative_pairs = sum(high_by_user[user] * low_by_user.get(user, 0) for user in high_by_user)
    return {
        "high_high_positive_pairs": positive_pairs,
        "high_low_negative_pairs": negative_pairs,
    }


def analyze_bias(books: list[dict[str, str]], users: list[dict[str, str]]) -> dict[str, Any]:
    years = Counter()
    publishers = Counter()
    authors = Counter()
    invalid_years = 0
    for book in books:
        year = parse_int(book.get("Year-Of-Publication", ""))
        if year is None or year <= 0:
            invalid_years += 1
        else:
            decade = f"{(year // 10) * 10}s"
            years[decade] += 1
        publishers[book.get("Publisher", "").strip() or "unknown"] += 1
        authors[book.get("Book-Author", "").strip() or "unknown"] += 1

    countries = Counter()
    ages = Counter()
    invalid_ages = 0
    for user in users:
        location = user.get("Location", "")
        country = location.split(",")[-1].strip().lower() if location else "unknown"
        countries[country or "unknown"] += 1
        age = parse_int(user.get("Age", ""))
        if age is None or age <= 0 or age > 120:
            invalid_ages += 1
        else:
            ages[f"{(age // 10) * 10}s"] += 1

    return {
        "publication_decades_top": dict(years.most_common(12)),
        "invalid_publication_years": invalid_years,
        "top_publishers": dict(publishers.most_common(20)),
        "top_authors": dict(authors.most_common(20)),
        "top_user_countries": dict(countries.most_common(20)) if users else {},
        "age_buckets": dict(ages.most_common(12)) if users else {},
        "invalid_ages": invalid_ages if users else 0,
        "known_biases": [
            "Kaggle Book-Crossing data is not Korean library behavior.",
            "ISBN coverage may skew toward older or Western-market books.",
            "Implicit zero ratings should not be treated as dislikes.",
        ],
    }


def review_decision(
    schema: dict[str, dict[str, Any]],
    rating_stats: dict[str, Any],
    pair_stats: dict[str, int],
) -> str:
    if schema["books"]["status"] != "ok" or schema["ratings"]["status"] != "ok":
        return "reject_missing_required_columns"
    if rating_stats["isbn_normalization_rate"] < 0.5:
        return "reject_low_isbn_normalization"
    if pair_stats["high_high_positive_pairs"] < 100:
        return "review_only_too_few_positive_pairs"
    return "usable_as_auxiliary_pretraining"


def recommendation_notes(
    decision: str,
    schema: dict[str, dict[str, Any]],
    rating_stats: dict[str, Any],
    pair_stats: dict[str, int],
) -> list[str]:
    notes = []
    if decision.startswith("reject"):
        notes.append("Do not use this dataset for training until the reported issue is fixed.")
    if schema.get("users", {}).get("status") == "not_provided":
        notes.append("Users.csv was not provided, so geographic and age bias checks are incomplete.")
    if rating_stats["isbn_match_rate"] < 0.8:
        notes.append("Many rating ISBNs do not match Books.csv after normalization; inspect source files.")
    if pair_stats["high_low_negative_pairs"] == 0:
        notes.append("No explicit low-rating negative pairs were found; sample random negatives carefully.")
    notes.append("Keep Data4Library test metrics as the final model acceptance gate.")
    return notes


def read_csv_rows(path: Path, max_rows: int = 0) -> list[dict[str, str]]:
    raw = read_text(path)
    sample = raw[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;")
    except csv.Error:
        dialect = csv.excel
    reader = csv.DictReader(raw.splitlines(), dialect=dialect)
    rows = []
    for index, row in enumerate(reader):
        rows.append({key: value for key, value in row.items() if key is not None})
        if max_rows > 0 and index + 1 >= max_rows:
            break
    return rows


def read_text(path: Path) -> str:
    for encoding in ("utf-8-sig", "latin-1"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="replace")


def demo_data() -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    raw_books = [
        {
            "ISBN": "0439139597",
            "Book-Title": "Harry Potter and the Goblet of Fire",
            "Book-Author": "J. K. Rowling",
            "Year-Of-Publication": "2000",
            "Publisher": "Scholastic",
        },
        {
            "ISBN": "9780140283334",
            "Book-Title": "Interpreter of Maladies",
            "Book-Author": "Jhumpa Lahiri",
            "Year-Of-Publication": "1999",
            "Publisher": "Penguin",
        },
        {
            "ISBN": "0316769487",
            "Book-Title": "The Catcher in the Rye",
            "Book-Author": "J. D. Salinger",
            "Year-Of-Publication": "1991",
            "Publisher": "Little Brown",
        },
    ]
    books = []
    for index in range(1, 17):
        books.append({
            "ISBN": demo_isbn13(index),
            "Book-Title": f"Demo High Rated Book {index}",
            "Book-Author": f"Demo Author {index}",
            "Year-Of-Publication": str(1990 + index),
            "Publisher": "Demo Publisher",
        })
    for index, book in enumerate(raw_books, start=17):
        copied = dict(book)
        copied["ISBN"] = demo_isbn13(index)
        books.append(copied)

    ratings = [
        {"User-ID": "1", "ISBN": demo_isbn13(index), "Book-Rating": "9"}
        for index in range(1, 16)
    ]
    ratings.extend([
        {"User-ID": "1", "ISBN": demo_isbn13(16), "Book-Rating": "2"},
        {"User-ID": "2", "ISBN": demo_isbn13(17), "Book-Rating": "0"},
        {"User-ID": "2", "ISBN": demo_isbn13(18), "Book-Rating": "8"},
        {"User-ID": "2", "ISBN": demo_isbn13(19), "Book-Rating": "4"},
    ])
    users = [
        {"User-ID": "1", "Location": "seattle, washington, usa", "Age": "34"},
        {"User-ID": "2", "Location": "toronto, ontario, canada", "Age": "28"},
    ]
    return books, ratings, users


def demo_isbn13(index: int) -> str:
    prefix = f"978000000{index:03d}"
    total = sum((1 if position % 2 == 0 else 3) * int(char) for position, char in enumerate(prefix))
    check = (10 - (total % 10)) % 10
    return prefix + str(check)


def normalize_isbn13(value: str) -> str:
    cleaned = re.sub(r"[^0-9Xx]", "", value)
    if len(cleaned) == 13 and cleaned.isdigit() and valid_isbn13(cleaned):
        return cleaned
    if len(cleaned) == 10 and valid_isbn10(cleaned):
        return isbn10_to_isbn13(cleaned)
    return ""


def valid_isbn10(value: str) -> bool:
    if len(value) != 10 or not re.match(r"^[0-9]{9}[0-9Xx]$", value):
        return False
    total = 0
    for index, char in enumerate(value):
        digit = 10 if char.upper() == "X" else int(char)
        total += digit * (10 - index)
    return total % 11 == 0


def valid_isbn13(value: str) -> bool:
    if len(value) != 13 or not value.isdigit():
        return False
    total = sum((1 if index % 2 == 0 else 3) * int(char) for index, char in enumerate(value))
    return total % 10 == 0


def isbn10_to_isbn13(value: str) -> str:
    prefix = "978" + value[:9]
    total = sum((1 if index % 2 == 0 else 3) * int(char) for index, char in enumerate(prefix))
    check = (10 - (total % 10)) % 10
    return prefix + str(check)


def parse_int(value: str | None) -> int | None:
    if value is None:
        return None
    try:
        return int(float(value.strip()))
    except ValueError:
        return None


def combinations_2(value: int) -> int:
    return value * (value - 1) // 2 if value >= 2 else 0


def ratio(numerator: int, denominator: int) -> float:
    return numerator / denominator if denominator else 0.0


def mean(values: Iterable[int]) -> float | None:
    values = list(values)
    return sum(values) / len(values) if values else None


if __name__ == "__main__":
    sys.exit(main())
