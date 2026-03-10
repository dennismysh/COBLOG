#!/usr/bin/env bash
# ============================================================
# COBLOG Build Script
# Orchestrates: prep → sort → generate → deploy
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

POSTS_DIR="${POSTS_DIR:-./posts}"
OUT_DIR="${OUT_DIR:-./out}"
BASE_URL="${BASE_URL:-https://example.com}"

echo "=== COBLOG Build ==="
echo "Posts:    $POSTS_DIR"
echo "Output:   $OUT_DIR"
echo "Base URL: $BASE_URL"
echo ""

# Step 1: Build Rust preprocessor
echo "[1/5] Building mdprep (Rust)..."
cargo build --release -p mdprep
MDPREP="./target/release/mdprep"

# Step 2: Compile COBOL programs
echo "[2/5] Compiling COBOL programs..."
mkdir -p bin
cobc -x src/cobol/site.cob -o bin/site
cobc -x src/cobol/sort.cob -o bin/sort
cobc -x src/cobol/rss.cob -o bin/rss
cobc -x src/cobol/sitemap.cob -o bin/sitemap

# Step 3: Generate site HTML
echo "[3/5] Generating site..."
mkdir -p "$OUT_DIR"
BASE_URL="$BASE_URL" "$MDPREP" "$POSTS_DIR" | ./bin/sort | ./bin/site "$OUT_DIR"

# Step 4: Generate RSS feed
echo "[4/5] Generating RSS feed..."
BASE_URL="$BASE_URL" "$MDPREP" "$POSTS_DIR" | ./bin/sort --by=date-desc | ./bin/rss > "$OUT_DIR/feed.xml"

# Step 5: Generate sitemap
echo "[5/5] Generating sitemap..."
BASE_URL="$BASE_URL" "$MDPREP" "$POSTS_DIR" | ./bin/sitemap > "$OUT_DIR/sitemap.xml"

# Copy static assets
cp -r static/* "$OUT_DIR/" 2>/dev/null || true

echo ""
echo "=== Build complete ==="
echo "Site generated in $OUT_DIR/"
find "$OUT_DIR" -type f | sort | while read -r f; do
    echo "  $f"
done
