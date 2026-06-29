#!/usr/bin/env python3
"""Train Commendo's local Core ML recommendation ranker.

The pipeline intentionally uses only public/provider book relationships:

- A seed ISBN is treated as a synthetic 5-star local bookmark.
- Data4Library reader/mania recommendations become weak positive labels.
- Non-recommended books from the fetched candidate pool become neutral/negative
  examples depending on category overlap.

No real user bookmarks, reviews, search terms, or behavior logs are used.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import random
import re
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable

import numpy as np

FEATURE_NAMES = [
    "categoryAffinity",
    "keywordSimilarity",
    "authorAffinity",
    "ratingAffinity",
    "recencyScore",
    "publicationAge",
    "trendOrRelatedSignal",
]

BASELINE_WEIGHTS = np.array([1.3, 1.7, 1.2, 1.4, 0.6, 0.3, 0.4], dtype=float)
BASELINE_OFFSET = -1.2
DEFAULT_ALADIN_BASE_URL = "https://www.aladin.co.kr/ttb/api"
DEFAULT_DATA4LIBRARY_BASE_URL = "https://data4library.kr/api"
DATA4LIBRARY_SAMPLE_WEIGHT = 1.0
KAGGLE_SAMPLE_WEIGHT = 0.35


@dataclass(frozen=True)
class Book:
    isbn13: str
    title: str
    author: str
    publisher: str
    published_date: str
    category_name: str
    description: str


@dataclass(frozen=True)
class TrainingRow:
    seed_isbn13: str
    candidate_isbn13: str
    source: str
    sample_weight: float
    relation: str
    label: float
    categoryAffinity: float
    keywordSimilarity: float
    authorAffinity: float
    ratingAffinity: float
    recencyScore: float
    publicationAge: float
    trendOrRelatedSignal: float


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", help="CSV with an isbn13 column or one ISBN per row.")
    parser.add_argument("--output-dir", required=True, help="Directory for cache, rows, and report files.")
    parser.add_argument(
        "--model-output",
        help="Optional app model replacement path. Written only when acceptance passes unless --allow-rejected-model is set.",
    )
    parser.add_argument(
        "--allow-rejected-model",
        action="store_true",
        help="Write --model-output even when offline evaluation rejects the candidate.",
    )
    parser.add_argument("--max-seeds", type=int, default=0, help="Optional limit for quick experiments.")
    parser.add_argument("--negative-per-seed", type=int, default=8)
    parser.add_argument("--kaggle-books", help="Optional local Kaggle Books.csv for auxiliary training rows.")
    parser.add_argument("--kaggle-ratings", help="Optional local Kaggle Ratings.csv for auxiliary training rows.")
    parser.add_argument("--kaggle-users", help="Optional local Kaggle Users.csv for review bias reporting.")
    parser.add_argument("--kaggle-max-ratings", type=int, default=0, help="Optional cap for Kaggle review/rating reads.")
    parser.add_argument("--max-kaggle-rows", type=int, default=20_000)
    parser.add_argument("--kaggle-high-per-user", type=int, default=12)
    parser.add_argument("--kaggle-low-per-user", type=int, default=12)
    parser.add_argument("--demo-kaggle-data", action="store_true", help="Use deterministic local Kaggle fixture rows.")
    parser.add_argument("--epochs", type=int, default=1500)
    parser.add_argument("--learning-rate", type=float, default=0.08)
    parser.add_argument("--l2", type=float, default=0.01)
    parser.add_argument("--random-seed", type=int, default=42)
    parser.add_argument("--request-delay", type=float, default=0.15)
    parser.add_argument(
        "--demo-data",
        action="store_true",
        help="Use deterministic local fixture rows instead of calling provider APIs.",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    kaggle_review: dict[str, Any] | None = None
    if args.demo_data:
        data4library_rows = demo_training_rows()
    else:
        if not args.seeds:
            raise SystemExit("--seeds is required unless --demo-data is set.")
        aladin_key = required_env("ALADIN_API_KEY")
        data4library_key = required_env("DATA4LIBRARY_API_KEY")
        aladin_base_url = os.environ.get("ALADIN_API_BASE_URL", DEFAULT_ALADIN_BASE_URL)
        data4library_base_url = os.environ.get("DATA4LIBRARY_API_BASE_URL", DEFAULT_DATA4LIBRARY_BASE_URL)

        seeds = read_seed_isbns(Path(args.seeds))
        if args.max_seeds > 0:
            seeds = seeds[: args.max_seeds]
        if not seeds:
            raise SystemExit("No seed ISBNs found.")

        cache_dir = output_dir / "cache"
        cache_dir.mkdir(exist_ok=True)
        client = ProviderClient(
            aladin_api_key=aladin_key,
            data4library_api_key=data4library_key,
            aladin_base_url=aladin_base_url,
            data4library_base_url=data4library_base_url,
            cache_dir=cache_dir,
            request_delay=args.request_delay,
        )

        data4library_rows = collect_training_rows(
            seeds=seeds,
            client=client,
            negative_per_seed=args.negative_per_seed,
            random_seed=args.random_seed,
        )
    rows = list(data4library_rows)
    if args.demo_kaggle_data:
        kaggle_review, kaggle_rows = collect_demo_kaggle_rows(
            max_rows=args.max_kaggle_rows,
            high_per_user=args.kaggle_high_per_user,
            low_per_user=args.kaggle_low_per_user,
        )
        if kaggle_review["recommendation"]["decision"] == "usable_as_auxiliary_pretraining":
            rows.extend(kaggle_rows)
    elif args.kaggle_books or args.kaggle_ratings:
        if not args.kaggle_books or not args.kaggle_ratings:
            raise SystemExit("--kaggle-books and --kaggle-ratings must be provided together.")
        kaggle_review, kaggle_rows = collect_kaggle_rows(
            books_path=Path(args.kaggle_books),
            ratings_path=Path(args.kaggle_ratings),
            users_path=Path(args.kaggle_users) if args.kaggle_users else None,
            max_ratings=args.kaggle_max_ratings,
            max_rows=args.max_kaggle_rows,
            high_per_user=args.kaggle_high_per_user,
            low_per_user=args.kaggle_low_per_user,
        )
        if kaggle_review["recommendation"]["decision"] == "usable_as_auxiliary_pretraining":
            rows.extend(kaggle_rows)
    if not rows:
        raise SystemExit("No training rows generated.")

    rows_path = output_dir / "training_rows.csv"
    write_rows(rows_path, rows)

    split = split_rows_by_seed(data4library_rows)
    split["train"] = split["train"] + [row for row in rows if row.source == "kaggle"]
    model = train_logistic_model(
        rows=split["train"],
        epochs=args.epochs,
        learning_rate=args.learning_rate,
        l2=args.l2,
    )

    report = build_report(rows=rows, split=split, model=model, kaggle_review=kaggle_review)
    report_path = output_dir / "training_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    candidate_model_path = output_dir / "BookRecommendationRanker.candidate.mlmodel"
    export_coreml_model(
        weights=model["weights"],
        offset=model["offset"],
        output_path=candidate_model_path,
        report=report,
    )
    replacement_path = None
    if args.model_output:
        decision = report["acceptance"]["decision"]
        if decision == "accept" or args.allow_rejected_model:
            replacement_path = Path(args.model_output)
            export_coreml_model(
                weights=model["weights"],
                offset=model["offset"],
                output_path=replacement_path,
                report=report,
            )

    print(f"rows: {rows_path}")
    print(f"report: {report_path}")
    print(f"candidate_model: {candidate_model_path}")
    if args.model_output:
        if replacement_path is None:
            print(f"model_replacement: skipped ({report['acceptance']['decision']})")
        else:
            print(f"model_replacement: {replacement_path}")
    return 0


class ProviderClient:
    def __init__(
        self,
        aladin_api_key: str,
        data4library_api_key: str,
        aladin_base_url: str,
        data4library_base_url: str,
        cache_dir: Path,
        request_delay: float,
    ) -> None:
        self.aladin_api_key = aladin_api_key
        self.data4library_api_key = data4library_api_key
        self.aladin_base_url = aladin_base_url.rstrip("/")
        self.data4library_base_url = data4library_base_url.rstrip("/")
        self.cache_dir = cache_dir
        self.request_delay = request_delay

    def fetch_aladin_detail(self, isbn13: str) -> Book | None:
        try:
            payload = self._get_json(
                cache_key=f"aladin-detail-{isbn13}",
                url=f"{self.aladin_base_url}/ItemLookUp.aspx",
                params={
                    "ttbkey": self.aladin_api_key,
                    "ItemIdType": "ISBN13",
                    "ItemId": isbn13,
                    "Cover": "Big",
                    "output": "JS",
                    "Version": "20131101",
                    "OptResult": "Toc,Story,categoryIdList",
                },
            )
        except urllib.error.HTTPError as error:
            if error.code in (400, 404, 406):
                return None
            raise
        items = payload.get("item")
        if not isinstance(items, list) or not items:
            return None
        item = items[0]
        if not isinstance(item, dict):
            return None
        return Book(
            isbn13=text(item.get("isbn13")),
            title=text(item.get("title")),
            author=text(item.get("author")),
            publisher=text(item.get("publisher")),
            published_date=text(item.get("pubDate") or item.get("pubdate")),
            category_name=text(item.get("categoryName")),
            description=text(item.get("fullDescription") or item.get("description")),
        )

    def fetch_recommendations(self, isbn13: str, relation_type: str) -> list[str]:
        try:
            payload = self._get_json(
                cache_key=f"data4library-{relation_type}-{isbn13}",
                url=f"{self.data4library_base_url}/recommandList",
                params={
                    "authKey": self.data4library_api_key,
                    "isbn13": isbn13,
                    "type": relation_type,
                    "format": "json",
                },
            )
        except urllib.error.HTTPError as error:
            if error.code in (400, 404, 406):
                return []
            raise
        docs = payload.get("response", {}).get("docs", [])
        if not isinstance(docs, list):
            return []

        isbns: list[str] = []
        for entry in docs:
            if not isinstance(entry, dict):
                continue
            item = entry.get("book") or entry.get("doc")
            if not isinstance(item, dict):
                continue
            isbn = normalize_isbn(text(item.get("isbn13")))
            if isbn:
                isbns.append(isbn)
        return unique_preserving_order(isbns)

    def _get_json(self, cache_key: str, url: str, params: dict[str, str]) -> dict[str, Any]:
        cache_path = self.cache_dir / f"{cache_key}.json"
        if cache_path.exists():
            return json.loads(cache_path.read_text(encoding="utf-8"))

        full_url = f"{url}?{urllib.parse.urlencode(params)}"
        request = urllib.request.Request(full_url)
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
        cache_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        if self.request_delay > 0:
            time.sleep(self.request_delay)
        return payload


def collect_training_rows(
    seeds: list[str],
    client: ProviderClient,
    negative_per_seed: int,
    random_seed: int,
) -> list[TrainingRow]:
    rng = random.Random(random_seed)
    books: dict[str, Book] = {}
    positives_by_seed: dict[str, dict[str, str]] = {}

    for seed in seeds:
        seed_book = client.fetch_aladin_detail(seed)
        if seed_book is None or not seed_book.isbn13:
            continue
        books[seed_book.isbn13] = seed_book

        positives: dict[str, str] = {}
        for relation in ("reader", "mania"):
            for isbn in client.fetch_recommendations(seed_book.isbn13, relation):
                if isbn == seed_book.isbn13:
                    continue
                positives.setdefault(isbn, relation)
        positives_by_seed[seed_book.isbn13] = positives

        for isbn in positives:
            if isbn not in books:
                book = client.fetch_aladin_detail(isbn)
                if book is not None and book.isbn13:
                    books[book.isbn13] = book

    rows: list[TrainingRow] = []
    candidate_isbns = list(books.keys())

    for seed, positives in positives_by_seed.items():
        seed_book = books.get(seed)
        if seed_book is None:
            continue

        for candidate, relation in positives.items():
            candidate_book = books.get(candidate)
            if candidate_book is None:
                continue
            label = 1.0 if relation == "reader" else 0.85
            rows.append(make_row(seed_book, candidate_book, "data4library", DATA4LIBRARY_SAMPLE_WEIGHT, relation, label, relation_signal(label)))

        positive_set = set(positives)
        negative_pool = [
            isbn for isbn in candidate_isbns
            if isbn != seed and isbn not in positive_set
        ]
        rng.shuffle(negative_pool)

        added = 0
        for candidate in negative_pool:
            candidate_book = books[candidate]
            same_category = category_root(seed_book.category_name) == category_root(candidate_book.category_name)
            relation = "same_category_unrecommended" if same_category else "random_negative"
            label = 0.25 if same_category else 0.0
            signal = 0.15 if same_category else 0.0
            rows.append(make_row(seed_book, candidate_book, "data4library", DATA4LIBRARY_SAMPLE_WEIGHT, relation, label, signal))
            added += 1
            if added >= negative_per_seed:
                break

    return rows


def demo_training_rows() -> list[TrainingRow]:
    seeds = [
        Book(
            isbn13="9780000000001",
            title="Humanities Seed",
            author="Author A",
            publisher="Publisher",
            published_date="2024",
            category_name="Humanities>Philosophy",
            description="philosophy essay thought",
        ),
        Book(
            isbn13="9780000000002",
            title="Science Seed",
            author="Author B",
            publisher="Publisher",
            published_date="2023",
            category_name="Science>Technology",
            description="science technology future",
        ),
        Book(
            isbn13="9780000000003",
            title="Cooking Seed",
            author="Author C",
            publisher="Publisher",
            published_date="2022",
            category_name="Lifestyle>Cooking",
            description="cooking recipe kitchen",
        ),
    ]
    candidates = [
        Book("9780000000101", "Philosophy Reader", "Author X", "Publisher", "2025", "Humanities>Philosophy", "philosophy thought"),
        Book("9780000000102", "Essay Mania", "Author Y", "Publisher", "2021", "Humanities>Essay", "essay humanities"),
        Book("9780000000103", "Robotics Reader", "Author Z", "Publisher", "2025", "Science>Technology", "robotics technology"),
        Book("9780000000104", "Kitchen Mania", "Author W", "Publisher", "2024", "Lifestyle>Cooking", "recipe kitchen"),
        Book("9780000000105", "History Survey", "Author H", "Publisher", "2020", "Humanities>History", "archive society"),
        Book("9780000000106", "Biology Atlas", "Author I", "Publisher", "2019", "Science>Biology", "cell organism"),
        Book("9780000000201", "Unrelated Travel", "Author Q", "Publisher", "2018", "Travel>Guide", "travel map"),
        Book("9780000000202", "Old Business", "Author R", "Publisher", "2015", "Business>Management", "business management"),
    ]

    rows: list[TrainingRow] = []
    for seed in seeds:
        for candidate in candidates:
            same_root = category_root(seed.category_name) == category_root(candidate.category_name)
            related_keyword = bool(keywords(seed.description).intersection(keywords(candidate.description)))
            if same_root and related_keyword:
                relation = "reader"
                label = 1.0
                signal = 1.0
            elif same_root:
                relation = "same_category_unrecommended"
                label = 0.25
                signal = 0.15
            else:
                relation = "random_negative"
                label = 0.0
                signal = 0.0
            rows.append(make_row(seed, candidate, "data4library", DATA4LIBRARY_SAMPLE_WEIGHT, relation, label, signal))
    return rows


def collect_kaggle_rows(
    books_path: Path,
    ratings_path: Path,
    users_path: Path | None,
    max_ratings: int,
    max_rows: int,
    high_per_user: int,
    low_per_user: int,
) -> tuple[dict[str, Any], list[TrainingRow]]:
    import review_kaggle_dataset

    books = review_kaggle_dataset.read_csv_rows(books_path)
    ratings = review_kaggle_dataset.read_csv_rows(ratings_path, max_rows=max_ratings)
    users = review_kaggle_dataset.read_csv_rows(users_path) if users_path else []
    return collect_kaggle_rows_from_data(
        books=books,
        ratings=ratings,
        users=users,
        paths={"books": str(books_path), "ratings": str(ratings_path), "users": str(users_path) if users_path else None},
        max_rows=max_rows,
        high_per_user=high_per_user,
        low_per_user=low_per_user,
    )


def collect_demo_kaggle_rows(
    max_rows: int,
    high_per_user: int,
    low_per_user: int,
) -> tuple[dict[str, Any], list[TrainingRow]]:
    import review_kaggle_dataset

    books, ratings, users = review_kaggle_dataset.demo_data()
    return collect_kaggle_rows_from_data(
        books=books,
        ratings=ratings,
        users=users,
        paths={"books": "demo", "ratings": "demo", "users": "demo"},
        max_rows=max_rows,
        high_per_user=high_per_user,
        low_per_user=low_per_user,
    )


def collect_kaggle_rows_from_data(
    books: list[dict[str, str]],
    ratings: list[dict[str, str]],
    users: list[dict[str, str]],
    paths: dict[str, str | None],
    max_rows: int,
    high_per_user: int,
    low_per_user: int,
) -> tuple[dict[str, Any], list[TrainingRow]]:
    import review_kaggle_dataset

    review = review_kaggle_dataset.build_report(
        books=books,
        ratings=ratings,
        users=users,
        paths=paths,
    )
    if review["recommendation"]["decision"] != "usable_as_auxiliary_pretraining":
        return review, []

    book_by_isbn: dict[str, Book] = {}
    for row in books:
        isbn13 = normalize_isbn(row.get("ISBN", ""))
        if not isbn13:
            continue
        title = row.get("Book-Title", "").strip()
        author = row.get("Book-Author", "").strip()
        publisher = row.get("Publisher", "").strip()
        published_year = row.get("Year-Of-Publication", "").strip()
        if not title or not author or not publisher:
            continue
        book_by_isbn[isbn13] = Book(
            isbn13=isbn13,
            title=title,
            author=author,
            publisher=publisher,
            published_date=published_year,
            category_name="",
            description=" ".join([title, author, publisher]),
        )

    ratings_by_user: dict[str, dict[str, list[str]]] = {}
    for row in ratings:
        user = row.get("User-ID", "").strip()
        rating = parse_int(row.get("Book-Rating", ""))
        isbn13 = normalize_isbn(row.get("ISBN", ""))
        if not user or rating is None or rating == 0 or isbn13 not in book_by_isbn:
            continue
        buckets = ratings_by_user.setdefault(user, {"high": [], "low": []})
        if rating >= 8:
            buckets["high"].append(isbn13)
        elif 1 <= rating <= 4:
            buckets["low"].append(isbn13)

    rows: list[TrainingRow] = []
    for user in sorted(ratings_by_user):
        high = unique_preserving_order(ratings_by_user[user]["high"])[:high_per_user]
        low = unique_preserving_order(ratings_by_user[user]["low"])[:low_per_user]
        if len(high) >= 2:
            for index, seed in enumerate(high):
                for candidate in high[index + 1:]:
                    rows.append(make_row(book_by_isbn[seed], book_by_isbn[candidate], "kaggle", KAGGLE_SAMPLE_WEIGHT, "kaggle_high_high", 0.75, 0.2))
                    if max_rows > 0 and len(rows) >= max_rows:
                        return review, rows
                    rows.append(make_row(book_by_isbn[candidate], book_by_isbn[seed], "kaggle", KAGGLE_SAMPLE_WEIGHT, "kaggle_high_high", 0.75, 0.2))
                    if max_rows > 0 and len(rows) >= max_rows:
                        return review, rows
        for seed in high:
            for candidate in low:
                rows.append(make_row(book_by_isbn[seed], book_by_isbn[candidate], "kaggle", KAGGLE_SAMPLE_WEIGHT, "kaggle_high_low", 0.0, 0.0))
                if max_rows > 0 and len(rows) >= max_rows:
                    return review, rows
    return review, rows


def make_row(
    seed_book: Book,
    candidate_book: Book,
    source: str,
    sample_weight: float,
    relation: str,
    label: float,
    trend_or_related_signal: float,
) -> TrainingRow:
    seed_keywords = keywords(" ".join([
        seed_book.title,
        seed_book.author,
        seed_book.publisher,
        seed_book.description,
    ]))
    candidate_keywords = keywords(" ".join([
        candidate_book.title,
        candidate_book.author,
        candidate_book.publisher,
        candidate_book.category_name,
        candidate_book.description,
    ]))
    category_keywords = keywords(candidate_book.category_name)

    category_affinity = jaccard_like(category_keywords, seed_keywords)
    keyword_similarity = jaccard_like(candidate_keywords, seed_keywords)
    author_affinity = 1.0 if candidate_book.author and candidate_book.author == seed_book.author else 0.0
    rating_affinity = max(author_affinity, keyword_similarity)
    publication_age = publication_age_score(candidate_book.published_date)

    return TrainingRow(
        seed_isbn13=seed_book.isbn13,
        candidate_isbn13=candidate_book.isbn13,
        source=source,
        sample_weight=sample_weight,
        relation=relation,
        label=clamp(label),
        categoryAffinity=category_affinity,
        keywordSimilarity=keyword_similarity,
        authorAffinity=author_affinity,
        ratingAffinity=rating_affinity,
        recencyScore=1.0,
        publicationAge=publication_age,
        trendOrRelatedSignal=clamp(trend_or_related_signal),
    )


def train_logistic_model(
    rows: list[TrainingRow],
    epochs: int,
    learning_rate: float,
    l2: float,
) -> dict[str, Any]:
    if not rows:
        raise SystemExit("Training split is empty.")

    x = np.array([[getattr(row, name) for name in FEATURE_NAMES] for row in rows], dtype=float)
    y = np.array([row.label for row in rows], dtype=float)
    sample_weights = np.array([max(row.sample_weight, 0.0) for row in rows], dtype=float)
    sample_weight_sum = float(np.sum(sample_weights))
    if sample_weight_sum <= 0:
        raise SystemExit("Training rows have no positive sample weight.")
    weights = BASELINE_WEIGHTS.copy()
    offset = BASELINE_OFFSET

    for _ in range(epochs):
        prediction = sigmoid(np.matmul(x, weights) + offset)
        error = (prediction - y) * sample_weights
        grad_weights = np.matmul(x.T, error) / sample_weight_sum + l2 * weights
        grad_offset = float(np.sum(error) / sample_weight_sum)
        weights -= learning_rate * grad_weights
        offset -= learning_rate * grad_offset

    return {
        "weights": weights,
        "offset": float(offset),
        "epochs": epochs,
        "learning_rate": learning_rate,
        "l2": l2,
    }


def build_report(
    rows: list[TrainingRow],
    split: dict[str, list[TrainingRow]],
    model: dict[str, Any],
    kaggle_review: dict[str, Any] | None,
) -> dict[str, Any]:
    trained_weights = np.array(model["weights"], dtype=float)
    trained_offset = float(model["offset"])

    return {
        "row_count": len(rows),
        "source_counts": count_by(rows, "source"),
        "sample_weight_counts": count_by(rows, "sample_weight"),
        "relation_counts": count_by(rows, "relation"),
        "split_counts": {name: len(values) for name, values in split.items()},
        "feature_names": FEATURE_NAMES,
        "kaggle": kaggle_report_summary(kaggle_review, rows),
        "candidate_model": {
            "weights": dict(zip(FEATURE_NAMES, trained_weights.tolist())),
            "offset": trained_offset,
            "train": {
                "epochs": model["epochs"],
                "learning_rate": model["learning_rate"],
                "l2": model["l2"],
            },
            "metrics": {name: metrics(values, trained_weights, trained_offset) for name, values in split.items()},
        },
        "baseline_model": {
            "weights": dict(zip(FEATURE_NAMES, BASELINE_WEIGHTS.tolist())),
            "offset": BASELINE_OFFSET,
            "metrics": {name: metrics(values, BASELINE_WEIGHTS, BASELINE_OFFSET) for name, values in split.items()},
        },
        "acceptance": {
            "rule": "Accept if candidate improves Data4Library test auc or positive_at_top_k and does not worsen Data4Library test log_loss.",
            "decision": acceptance_decision(split["test"], trained_weights, trained_offset),
        },
        "sample_predictions": sample_predictions(split["test"], trained_weights, trained_offset),
    }


def acceptance_decision(rows: list[TrainingRow], weights: np.ndarray, offset: float) -> str:
    candidate = metrics(rows, weights, offset)
    baseline = metrics(rows, BASELINE_WEIGHTS, BASELINE_OFFSET)
    if not candidate or not baseline:
        return "insufficient_test_data"
    improved_rank = (
        candidate["auc"] > baseline["auc"]
        or candidate["positive_at_top_k"] > baseline["positive_at_top_k"]
    )
    log_loss_ok = candidate["log_loss"] <= baseline["log_loss"]
    return "accept" if improved_rank and log_loss_ok else "reject"


def kaggle_report_summary(kaggle_review: dict[str, Any] | None, rows: list[TrainingRow]) -> dict[str, Any]:
    kaggle_rows = [row for row in rows if row.source == "kaggle"]
    if kaggle_review is None:
        return {
            "decision": "not_provided",
            "included_in_training": False,
            "row_count": 0,
        }
    decision = kaggle_review["recommendation"]["decision"]
    return {
        "decision": decision,
        "included_in_training": bool(kaggle_rows),
        "row_count": len(kaggle_rows),
        "sample_weight": KAGGLE_SAMPLE_WEIGHT,
        "kaggle_skipped": decision != "usable_as_auxiliary_pretraining",
        "review": kaggle_review,
    }


def metrics(rows: list[TrainingRow], weights: np.ndarray, offset: float) -> dict[str, float]:
    if not rows:
        return {}
    labels = np.array([row.label for row in rows], dtype=float)
    hard_labels = np.array([1 if row.label >= 0.5 else 0 for row in rows], dtype=int)
    predictions = predict_rows(rows, weights, offset)
    return {
        "auc": auc(hard_labels, predictions),
        "log_loss": log_loss(labels, predictions),
        "positive_at_top_k": positive_at_top_k(rows, predictions),
        "positive_pair_win_rate": positive_pair_win_rate(rows, predictions),
    }


def export_coreml_model(
    weights: np.ndarray,
    offset: float,
    output_path: Path,
    report: dict[str, Any],
) -> None:
    try:
        from coremltools.proto import Model_pb2
    except ImportError as error:
        raise SystemExit("coremltools is required to export .mlmodel.") from error

    model = Model_pb2.Model()
    model.specificationVersion = 1
    model.description.predictedFeatureName = "score"
    model.description.metadata.shortDescription = "Weak-label Data4Library book recommendation ranker."
    model.description.metadata.author = "Commendo"
    model.description.metadata.versionString = "1.1.0"
    model.description.metadata.license = "Proprietary"
    model.description.metadata.userDefined["privacy"] = (
        "Trained from Data4Library recommendation relations, not real user behavior."
    )
    model.description.metadata.userDefined["featureContract"] = ",".join(FEATURE_NAMES)
    model.description.metadata.userDefined["trainingDecision"] = report["acceptance"]["decision"]

    for name in FEATURE_NAMES:
        feature = model.description.input.add()
        feature.name = name
        feature.type.doubleType.MergeFrom(feature.type.doubleType)

    output = model.description.output.add()
    output.name = "score"
    output.type.doubleType.MergeFrom(output.type.doubleType)

    glm_weights = model.glmRegressor.weights.add()
    glm_weights.value.extend([float(value) for value in weights])
    model.glmRegressor.offset.append(float(offset))
    model.glmRegressor.postEvaluationTransform = Model_pb2.GLMRegressor.Logit

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(model.SerializeToString())


def split_rows_by_seed(rows: list[TrainingRow]) -> dict[str, list[TrainingRow]]:
    split = {"train": [], "validation": [], "test": []}
    for row in rows:
        bucket = stable_bucket(row.seed_isbn13)
        if bucket < 70:
            split["train"].append(row)
        elif bucket < 85:
            split["validation"].append(row)
        else:
            split["test"].append(row)
    if rows and any(len(values) == 0 for values in split.values()):
        return split_rows_by_sorted_seed(rows)
    return split


def split_rows_by_sorted_seed(rows: list[TrainingRow]) -> dict[str, list[TrainingRow]]:
    seeds = sorted({row.seed_isbn13 for row in rows})
    split_names = ["train", "validation", "test"]
    seed_to_split = {
        seed: split_names[index % len(split_names)]
        for index, seed in enumerate(seeds)
    }
    split = {"train": [], "validation": [], "test": []}
    for row in rows:
        split[seed_to_split[row.seed_isbn13]].append(row)
    return split


def stable_bucket(value: str) -> int:
    digest = hashlib.sha256(value.encode("utf-8")).hexdigest()
    return int(digest[:8], 16) % 100


def predict_rows(rows: list[TrainingRow], weights: np.ndarray, offset: float) -> np.ndarray:
    x = np.array([[getattr(row, name) for name in FEATURE_NAMES] for row in rows], dtype=float)
    return sigmoid(np.matmul(x, weights) + offset)


def sigmoid(value: np.ndarray | float) -> np.ndarray | float:
    return 1 / (1 + np.exp(-value))


def auc(labels: np.ndarray, predictions: np.ndarray) -> float:
    positives = predictions[labels == 1]
    negatives = predictions[labels == 0]
    if len(positives) == 0 or len(negatives) == 0:
        return 0.5
    wins = 0.0
    total = 0
    for positive in positives:
        wins += float(np.sum(positive > negatives))
        wins += 0.5 * float(np.sum(positive == negatives))
        total += len(negatives)
    return wins / total if total else 0.5


def log_loss(labels: np.ndarray, predictions: np.ndarray) -> float:
    clipped = np.clip(predictions, 1e-6, 1 - 1e-6)
    losses = -(labels * np.log(clipped) + (1 - labels) * np.log(1 - clipped))
    return float(np.mean(losses))


def positive_at_top_k(rows: list[TrainingRow], predictions: np.ndarray, k: int = 5) -> float:
    grouped: dict[str, list[tuple[TrainingRow, float]]] = {}
    for row, prediction in zip(rows, predictions):
        grouped.setdefault(row.seed_isbn13, []).append((row, float(prediction)))
    if not grouped:
        return 0.0
    scores = []
    for group in grouped.values():
        top = sorted(group, key=lambda item: item[1], reverse=True)[:k]
        scores.append(sum(1 for row, _ in top if row.label >= 0.5) / max(len(top), 1))
    return float(np.mean(scores))


def positive_pair_win_rate(rows: list[TrainingRow], predictions: np.ndarray) -> float:
    grouped: dict[str, list[tuple[TrainingRow, float]]] = {}
    for row, prediction in zip(rows, predictions):
        grouped.setdefault(row.seed_isbn13, []).append((row, float(prediction)))
    wins = 0
    total = 0
    for group in grouped.values():
        positives = [score for row, score in group if row.label >= 0.5]
        negatives = [score for row, score in group if row.label < 0.5]
        for positive in positives:
            for negative in negatives:
                total += 1
                if positive > negative:
                    wins += 1
    return wins / total if total else 0.0


def sample_predictions(rows: list[TrainingRow], weights: np.ndarray, offset: float, limit: int = 20) -> list[dict[str, Any]]:
    predictions = predict_rows(rows[:limit], weights, offset) if rows else []
    return [
        {
            "seed_isbn13": row.seed_isbn13,
            "candidate_isbn13": row.candidate_isbn13,
            "source": row.source,
            "relation": row.relation,
            "label": row.label,
            "sample_weight": row.sample_weight,
            "score": float(score),
        }
        for row, score in zip(rows[:limit], predictions)
    ]


def write_rows(path: Path, rows: list[TrainingRow]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(asdict(rows[0]).keys()))
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def read_seed_isbns(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8-sig")
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return []
    if "," not in lines[0] and normalize_isbn(lines[0]):
        return unique_preserving_order([normalize_isbn(line) for line in lines if normalize_isbn(line)])

    reader = csv.DictReader(lines)
    seeds = []
    for row in reader:
        value = row.get("isbn13") or row.get("isbn") or next(iter(row.values()), "")
        isbn = normalize_isbn(value)
        if isbn:
            seeds.append(isbn)
    return unique_preserving_order(seeds)


def keywords(value: str) -> set[str]:
    return {
        token
        for token in re.split(r"[^0-9A-Za-z가-힣]+", value.lower())
        if len(token) >= 2
    }


def jaccard_like(candidate: set[str], preferred: set[str]) -> float:
    if not candidate or not preferred:
        return 0.0
    return clamp(len(candidate.intersection(preferred)) / max(len(candidate), 1))


def publication_age_score(value: str) -> float:
    match = re.match(r"(\d{4})", value)
    if not match:
        return 0.0
    year = int(match.group(1))
    current_year = time.gmtime().tm_year
    age = max(0, current_year - year)
    return clamp(1 - min(age / 10, 1))


def category_root(value: str) -> str:
    return value.split(">")[0].strip() if value else ""


def relation_signal(label: float) -> float:
    return clamp(label)


def normalize_isbn(value: str) -> str:
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


def unique_preserving_order(values: Iterable[str]) -> list[str]:
    seen = set()
    unique = []
    for value in values:
        if value and value not in seen:
            seen.add(value)
            unique.append(value)
    return unique


def count_by(rows: list[TrainingRow], field_name: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in rows:
        key = str(getattr(row, field_name))
        counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items()))


def parse_int(value: str | None) -> int | None:
    if value is None:
        return None
    try:
        return int(float(value.strip()))
    except ValueError:
        return None


def text(value: Any) -> str:
    return value if isinstance(value, str) else ""


def clamp(value: float) -> float:
    return min(1.0, max(0.0, float(value)))


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


if __name__ == "__main__":
    sys.exit(main())
