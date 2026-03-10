---
title: "Report Writer: The Original Template Engine"
date: 2026-03-08
author: "beanieandpen"
tag: "technical"
description: "A deep dive into COBOL Report Writer and why its control break model maps perfectly to static site generation."
slug: "report-writer-deep-dive"
---

## Control Breaks Are Template Logic

When the Report Writer detects a change in a sort key, it fires a control break. This is exactly what a template engine does when it groups posts by tag or paginates by count.

The difference is that COBOL makes the grouping logic a first-class part of the language specification, not a library feature that might change with the next major version.

## Report Sections Map to HTML

Consider the mapping:

- **REPORT HEADING** emits `<html><head>` with all meta tags
- **CONTROL HEADING** emits `<section><h2>` for each tag group
- **DETAIL** emits the actual content lines
- **CONTROL FOOTING** closes the section
- **REPORT FOOTING** emits the footer and closes the document

This isn't a metaphor. It's a direct structural correspondence.

## Why Fixed-Width Records?

COBOL's native I/O model is sequential fixed-length records. By converting Markdown to this format in the Rust preprocessor, we speak COBOL's language natively.

No parsing. No deserialization. Just sequential reads of known-width fields. The COBOL program never needs to handle variable-length input or deal with encoding issues.

This is the lingua franca between the Rust and COBOL stages of the pipeline.
