---
title: "Building a Rust-to-COBOL Pipeline"
date: 2026-03-05
author: "beanieandpen"
tag: "technical"
description: "How mdprep bridges modern Rust tooling with COBOL's fixed-width record model for a zero-dependency static site."
slug: "rust-cobol-pipeline"
---

## Two Languages, One Pipeline

The Rust preprocessor, mdprep, handles everything that COBOL shouldn't: Markdown parsing, YAML frontmatter extraction, UTF-8 normalization, and JSON-LD serialization.

COBOL handles everything that Rust doesn't need to: document structure, control breaks, section headings, and file output.

Neither language does the other's job.

## The Record Format

Each Markdown post becomes N fixed-width records, one per body line. The header fields repeat on every record:

- `POST-DATE` (8 bytes): YYYYMMDD
- `POST-SLUG` (60 bytes): URL-safe identifier
- `POST-TITLE` (120 bytes): Human-readable title
- `POST-AUTHOR` (40 bytes): Attribution
- `POST-TAG` (30 bytes): Primary category
- `POST-DESC` (160 bytes): Meta description
- `POST-CANONICAL` (120 bytes): Full URL
- `POST-JSON-LD` (800 bytes): Serialized structured data
- `POST-BODY-LINE` (200 bytes): One line of HTML content

Total: 1,538 bytes per record. Predictable. Auditable. Fast.

## Why This Works

COBOL was built for batch processing of sequential records. A blog is a batch of sequential records. The impedance mismatch is zero.
