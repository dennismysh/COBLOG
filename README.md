# COBLOG

A static site generator that uses **COBOL Report Writer** as its template engine.

Markdown posts go in, fixed-width records flow through a COBOL SORT, and pure HTML/CSS comes out — no JavaScript, no frameworks, no runtime dependencies.

## Why COBOL?

A blog is fundamentally a batch of sequential records. COBOL's fixed-width record model, SORT verb, and Report Writer were designed in the 1960s for exactly this: turning sequential data into structured documents with control breaks. COBLOG uses that machinery instead of reinventing it with JavaScript abstractions.

## Architecture

```
Markdown + YAML frontmatter
        │
        ▼
   ┌─────────┐
   │  mdprep  │  Rust – parses frontmatter, converts Markdown → HTML,
   │  (Rust)  │  emits fixed-width 1,538-byte records to stdout
   └────┬─────┘
        │  piped
        ▼
   ┌─────────┐
   │  sort    │  COBOL – multi-key sort (tag+date, date-desc, author+date)
   └────┬─────┘
        │  piped
        ▼
   ┌──────────────────────────┐
   │  site / rss / sitemap    │  COBOL – reads sorted records,
   │  (COBOL Report Writer)   │  generates HTML pages, RSS 2.0, XML sitemap
   └──────────────────────────┘
        │
        ▼
   out/  ← zero-JS static site
```

Each Markdown post becomes *N* records (one per body line), allowing COBOL control breaks on slug to collect lines into complete pages.

## Features

- **Markdown → HTML** with YAML frontmatter (title, date, author, tag, description, slug)
- **Multi-key sorting** — by tag+date (index), date-desc (RSS), date-asc, or author+date
- **Individual post pages** and a grouped **index page**
- **RSS 2.0 feed** (top 20 items)
- **XML sitemap**
- **JSON-LD** structured data (BlogPosting schema) for SEO
- **Open Graph** and canonical meta tags
- **Dark mode** support via `prefers-color-scheme`
- **GitHub Pages** deployment via GitHub Actions
- **Zero JavaScript** — the generated site is pure HTML and CSS

## Prerequisites

- [GnuCOBOL](https://gnucobol.sourceforge.io/) (`cobc`)
- [Rust](https://rustup.rs/) toolchain (stable)
- Bash or Make

```bash
# Debian/Ubuntu
sudo apt-get install gnucobol

# macOS (Homebrew)
brew install gnucobol
```

## Quick Start

```bash
git clone https://github.com/dennismysh/COBLOG.git
cd COBLOG

# Build and generate the site
./build.sh

# Or use Make
make all
```

The generated site will be in `./out/`.

## Makefile Targets

| Target     | Description                          |
|------------|--------------------------------------|
| `make all` | Build everything and generate site   |
| `make prep`| Build the Rust preprocessor          |
| `make build`| Compile COBOL programs              |
| `make generate`| Run the pipeline, produce HTML   |
| `make rss` | Generate RSS feed                    |
| `make sitemap`| Generate XML sitemap              |
| `make clean`| Remove build artifacts              |

## Writing Posts

Create a Markdown file in `posts/` with YAML frontmatter:

```markdown
---
title: "Your Post Title"
date: 2026-03-10
author: "yourname"
tag: "topic"
description: "A short summary of the post."
slug: "your-post-title"
---

Post content goes here. Standard Markdown is supported:
**bold**, *italic*, `code`, links, lists, headings, blockquotes, and code blocks.
```

Rebuild the site and your post appears.

## Environment Variables

| Variable    | Default               | Purpose                                      |
|-------------|-----------------------|----------------------------------------------|
| `BASE_URL`  | `https://example.com` | Base URL for canonical links, feed, sitemap   |
| `BASE_PATH` | *(empty)*             | Subpath for GitHub project pages (e.g. `/COBLOG`) |
| `POSTS_DIR` | `./posts`             | Directory containing Markdown posts           |
| `OUT_DIR`   | `./out`               | Output directory for the generated site       |

## Project Structure

```
COBLOG/
├── src/
│   ├── main.rs              # Rust preprocessor (mdprep)
│   └── cobol/
│       ├── site.cob          # HTML page generator
│       ├── sort.cob          # Multi-key sort driver
│       ├── rss.cob           # RSS 2.0 feed generator
│       └── sitemap.cob       # XML sitemap generator
├── posts/                    # Markdown blog posts
├── static/                   # CSS and static assets
├── build.sh                  # Build orchestration script
├── Makefile                  # Make-based build
├── Cargo.toml                # Rust package manifest
└── .github/workflows/
    └── deploy.yml            # GitHub Actions CI/CD
```

## Fixed-Width Record Format

The bridge between Rust and COBOL is a 1,538-byte fixed-width record:

| Field     | Size  | Description                       |
|-----------|-------|-----------------------------------|
| DATE      | 8     | `YYYYMMDD`                        |
| SLUG      | 60    | URL-safe post identifier          |
| TITLE     | 120   | Post title                        |
| AUTHOR    | 40    | Author name                       |
| TAG       | 30    | Topic tag                         |
| DESC      | 160   | Meta description                  |
| CANONICAL | 120   | Canonical URL                     |
| JSON-LD   | 800   | Structured data for SEO           |
| BODY-LINE | 200   | One line of rendered HTML body    |

## Deployment

Push to `main` and GitHub Actions will build the site and deploy to GitHub Pages automatically. The workflow triggers on changes to `posts/`, `src/`, `static/`, `Makefile`, `Cargo.toml`, or `build.sh`.

## License

[MIT](LICENSE) — Dennis Myshkovskiy
