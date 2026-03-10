---
title: "Hello, COBLOG"
date: 2026-03-10
author: "beanieandpen"
tag: "meta"
description: "Introducing COBLOG: a static site generator that uses COBOL Report Writer as its template engine."
slug: "hello-coblog"
---

## Why COBOL?

COBOL's Report Writer was designed in the 1960s for exactly one thing: taking sequential records and turning them into structured documents with automatic group handling, control breaks, and page management.

Modern static site generators reinvent this with JavaScript abstractions. We're going back to the source.

## How It Works

The pipeline is simple:

1. Write posts in Markdown with YAML frontmatter
2. A Rust preprocessor converts them to fixed-width records
3. COBOL's SORT verb orders them by tag, date, or author
4. The Report Writer emits clean, semantic HTML

No JavaScript runtime. No framework dependencies. No node_modules folder the size of a small country.

## The Architecture

Every layout decision is explicit in COBOL source that compiles to a small native binary and generates a full site in under 100ms.

The template *is* the specification. The specification *is* the template.

Software made with intention.
