# COBLOG — COBOL Blog Engine
# GnuCOBOL Report Writer + Rust preprocessing pipeline

COBC      := cobc
CARGO     := cargo
MDPREP    := ./target/release/mdprep
SITE_BIN  := ./bin/site
SORT_BIN  := ./bin/sort
RSS_BIN   := ./bin/rss
SITEMAP_BIN := ./bin/sitemap
POSTS_DIR := ./posts
OUT_DIR   := ./out
BASE_URL  ?= https://example.com

.PHONY: all prep build generate rss sitemap clean deploy

all: prep build generate rss sitemap

# Build Rust preprocessor
prep:
	$(CARGO) build --release -p mdprep

# Compile COBOL programs
build: $(SITE_BIN) $(SORT_BIN) $(RSS_BIN) $(SITEMAP_BIN)

$(SITE_BIN): src/cobol/site.cob
	@mkdir -p bin
	$(COBC) -x $< -o $@

$(SORT_BIN): src/cobol/sort.cob
	@mkdir -p bin
	$(COBC) -x $< -o $@

$(RSS_BIN): src/cobol/rss.cob
	@mkdir -p bin
	$(COBC) -x $< -o $@

$(SITEMAP_BIN): src/cobol/sitemap.cob
	@mkdir -p bin
	$(COBC) -x $< -o $@

# Generate site HTML
generate: prep build
	@mkdir -p $(OUT_DIR)
	BASE_URL=$(BASE_URL) $(MDPREP) $(POSTS_DIR) | $(SORT_BIN) | $(SITE_BIN) $(OUT_DIR)
	@cp -r static/* $(OUT_DIR)/ 2>/dev/null || true

# Generate RSS feed
rss: prep build
	@mkdir -p $(OUT_DIR)
	BASE_URL=$(BASE_URL) $(MDPREP) $(POSTS_DIR) | $(SORT_BIN) --by=date-desc | $(RSS_BIN) > $(OUT_DIR)/feed.xml

# Generate sitemap
sitemap: prep build
	@mkdir -p $(OUT_DIR)
	BASE_URL=$(BASE_URL) $(MDPREP) $(POSTS_DIR) | $(SITEMAP_BIN) > $(OUT_DIR)/sitemap.xml

# Clean build artifacts
clean:
	rm -rf bin/ out/ target/

# Deploy (customize for your host)
deploy: all
	@echo "Site generated in $(OUT_DIR)/"
