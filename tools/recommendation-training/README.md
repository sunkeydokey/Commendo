# Recommendation Training

Local-only pipeline for replacing `Commendo/Recommendation/BookRecommendationRanker.mlmodel`
with a Data4Library weak-label model.

This does not use real user bookmarks, reviews, search terms, or behavior logs.
The seed ISBN is treated as a synthetic 5-star bookmark, and Data4Library
`recommandList` relations provide weak labels.

## Inputs

Create a seed CSV with one ISBN per row:

```csv
isbn13
9788936434120
9788954682152
```

Required environment variables:

```sh
export ALADIN_API_KEY=...
export DATA4LIBRARY_API_KEY=...
```

Optional base URL overrides:

```sh
export ALADIN_API_BASE_URL=https://www.aladin.co.kr/ttb/api
export DATA4LIBRARY_API_BASE_URL=https://data4library.kr/api
```

## Run

```sh
python3 -m venv /tmp/commendo-recommendation-training
/tmp/commendo-recommendation-training/bin/pip install -r tools/recommendation-training/requirements.txt
/tmp/commendo-recommendation-training/bin/python tools/recommendation-training/train_recommendation_ranker.py \
  --seeds path/to/seeds.csv \
  --output-dir /tmp/commendo-recommendation-training-output \
  --model-output Commendo/Recommendation/BookRecommendationRanker.mlmodel
```

The script writes:

- `training_rows.csv`: feature rows, weak labels, `source`, and `sample_weight`.
- `training_report.json`: split metrics, coefficients, and comparison with the current hand-weighted baseline.
- `BookRecommendationRanker.candidate.mlmodel`: candidate model with the existing app contract.

## Kaggle Auxiliary Rows

Kaggle data is optional auxiliary training data and is never used for final
acceptance metrics. Provide local CSVs only after running the review:

```sh
/tmp/commendo-recommendation-training/bin/python tools/recommendation-training/train_recommendation_ranker.py \
  --seeds path/to/seeds.csv \
  --output-dir /tmp/commendo-recommendation-training-output \
  --kaggle-books path/to/Books.csv \
  --kaggle-ratings path/to/Ratings.csv \
  --kaggle-users path/to/Users.csv
```

The training script reruns the same Kaggle review internally. Kaggle rows are
included only when the review decision is `usable_as_auxiliary_pretraining`;
otherwise the model falls back to Data4Library-only training and records
`kaggle_skipped` in `training_report.json`.

Data4Library rows use `sample_weight=1.0`. Kaggle rows use
`sample_weight=0.35` and are appended only to the train split. Validation, test,
and replacement acceptance remain Data4Library-only.

## Acceptance

Replace the app model only when the candidate improves either `auc` or
`positive_at_top_k` on the held-out test split and does not worsen `log_loss`
against the current baseline.

When `--model-output` is set, the script writes that replacement path only if
the acceptance rule passes. The candidate model is always written to the output
directory for inspection. Use `--allow-rejected-model` only for local debugging.

## Kaggle Augmentation Review

Kaggle data is not downloaded automatically. If you have accepted Kaggle's terms
and downloaded the Book Recommendation Dataset locally, review it before using it
as auxiliary pretraining data:

```sh
/tmp/commendo-recommendation-training/bin/python tools/recommendation-training/review_kaggle_dataset.py \
  --books path/to/Books.csv \
  --ratings path/to/Ratings.csv \
  --users path/to/Users.csv \
  --output-dir /tmp/commendo-kaggle-review
```

The review writes `kaggle_review_report.json` with:

- required schema checks for `Books.csv`, `Ratings.csv`, and optional `Users.csv`;
- ISBN-13 normalization and ratings-to-books match rates;
- rating bucket counts and high/high positive pair estimates;
- high/low negative pair estimates;
- publication year, publisher, author, country, and age bias summaries.

Kaggle rows are only candidates for auxiliary pretraining. Keep their sample
weight lower than Data4Library rows, do not treat implicit `Book-Rating = 0` as a
dislike, and keep Data4Library validation/test metrics as the final acceptance
gate before replacing the app model.

For a local smoke test without Kaggle files:

```sh
python3 tools/recommendation-training/review_kaggle_dataset.py \
  --demo-data \
  --output-dir /tmp/commendo-kaggle-review-demo
```

For a mixed training smoke test without Kaggle files:

```sh
python3 tools/recommendation-training/train_recommendation_ranker.py \
  --demo-data \
  --demo-kaggle-data \
  --output-dir /tmp/commendo-recommendation-training-demo
```

After replacing the model, verify:

```sh
xcrun coremlcompiler compile Commendo/Recommendation/BookRecommendationRanker.mlmodel /tmp/commendo-mlmodel-compile
xcodebuild build-for-testing -quiet -project Commendo.xcodeproj -scheme Commendo -destination 'generic/platform=iOS Simulator' -derivedDataPath .deriveddata
xcodebuild test-without-building -quiet -project Commendo.xcodeproj -scheme Commendo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .deriveddata -only-testing:CommendoTests
```
