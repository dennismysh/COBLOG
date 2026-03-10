use chrono::NaiveDate;
use clap::Parser;
use gray_matter::engine::YAML;
use gray_matter::Matter;
use pulldown_cmark::{Event, Parser as MdParser, Tag, TagEnd};
use serde::Deserialize;
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use walkdir::WalkDir;

/// Fixed-width record field sizes (must match COBOL PICTURE clauses)
const F_DATE: usize = 8;        // PIC 9(8)
const F_SLUG: usize = 60;       // PIC X(60)
const F_TITLE: usize = 120;     // PIC X(120)
const F_AUTHOR: usize = 40;     // PIC X(40)
const F_TAG: usize = 30;        // PIC X(30)
const F_DESC: usize = 160;      // PIC X(160)
const F_CANONICAL: usize = 120; // PIC X(120)
const F_JSONLD: usize = 800;    // PIC X(800)
const F_BODY: usize = 200;      // PIC X(200)

const RECORD_LEN: usize =
    F_DATE + F_SLUG + F_TITLE + F_AUTHOR + F_TAG + F_DESC + F_CANONICAL + F_JSONLD + F_BODY;

#[derive(Parser)]
#[command(name = "mdprep", about = "Markdown to fixed-width COBOL records")]
struct Cli {
    /// Directory containing .md post files
    posts_dir: PathBuf,
}

#[derive(Deserialize, Default, Debug)]
struct Frontmatter {
    title: Option<String>,
    date: Option<String>,
    author: Option<String>,
    tag: Option<String>,
    tags: Option<Vec<String>>,
    description: Option<String>,
    slug: Option<String>,
}

fn main() {
    let cli = Cli::parse();
    let base_url = env::var("BASE_URL").unwrap_or_else(|_| "https://example.com".to_string());
    let stdout = io::stdout();
    let mut out = stdout.lock();

    let mut entries: Vec<PathBuf> = WalkDir::new(&cli.posts_dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| {
            e.path()
                .extension()
                .map_or(false, |ext| ext == "md" || ext == "markdown")
        })
        .map(|e| e.into_path())
        .collect();

    entries.sort();

    for path in entries {
        if let Err(e) = process_post(&path, &base_url, &mut out) {
            eprintln!("mdprep: warning: {}: {}", path.display(), e);
        }
    }
}

fn process_post(path: &PathBuf, base_url: &str, out: &mut impl Write) -> Result<(), String> {
    let content = fs::read_to_string(path).map_err(|e| e.to_string())?;

    let matter = Matter::<YAML>::new();
    let parsed = matter.parse(&content);

    let fm: Frontmatter = parsed
        .data
        .as_ref()
        .and_then(|d| d.deserialize().ok())
        .unwrap_or_default();

    let title = fm.title.unwrap_or_else(|| {
        path.file_stem()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string()
    });

    let date_str = fm.date.unwrap_or_else(|| "20240101".to_string());
    let date = parse_date(&date_str)?;
    let date_yyyymmdd = date.format("%Y%m%d").to_string();
    let date_iso = date.format("%Y-%m-%d").to_string();

    let slug = fm.slug.unwrap_or_else(|| slugify(&title));
    let author = fm.author.unwrap_or_else(|| "Anonymous".to_string());

    // Support both `tag:` (single) and `tags:` (list) - use first tag
    let tag = fm
        .tag
        .or_else(|| fm.tags.and_then(|t| t.into_iter().next()))
        .unwrap_or_else(|| "uncategorized".to_string());

    let body_text = parsed.content.trim().to_string();

    // Extract plain text from markdown for description
    let plain = markdown_to_plain(&body_text);

    let description = fm.description.unwrap_or_else(|| {
        trim_to_word_boundary(&plain, 155)
    });

    let canonical = format!("{}/{}/", base_url.trim_end_matches('/'), slug);

    let json_ld = build_json_ld(&title, &description, &author, &date_iso, &canonical);
    if json_ld.len() > F_JSONLD {
        eprintln!(
            "mdprep: warning: JSON-LD for '{}' is {} bytes (max {}), truncating description",
            slug,
            json_ld.len(),
            F_JSONLD
        );
    }

    // Convert markdown body to HTML lines
    let html_body = markdown_to_html(&body_text);
    let body_lines = wrap_lines(&html_body, F_BODY);

    if body_lines.is_empty() {
        // Emit at least one record for empty posts
        write_record(
            out,
            &date_yyyymmdd,
            &slug,
            &title,
            &author,
            &tag,
            &description,
            &canonical,
            &json_ld,
            "",
        )?;
    } else {
        for line in &body_lines {
            write_record(
                out,
                &date_yyyymmdd,
                &slug,
                &title,
                &author,
                &tag,
                &description,
                &canonical,
                &json_ld,
                line,
            )?;
        }
    }

    Ok(())
}

fn write_record(
    out: &mut impl Write,
    date: &str,
    slug: &str,
    title: &str,
    author: &str,
    tag: &str,
    desc: &str,
    canonical: &str,
    json_ld: &str,
    body_line: &str,
) -> Result<(), String> {
    let record = format!(
        "{}{}{}{}{}{}{}{}{}",
        pad_or_truncate(date, F_DATE),
        pad_or_truncate(slug, F_SLUG),
        pad_or_truncate(title, F_TITLE),
        pad_or_truncate(author, F_AUTHOR),
        pad_or_truncate(tag, F_TAG),
        pad_or_truncate(desc, F_DESC),
        pad_or_truncate(canonical, F_CANONICAL),
        pad_or_truncate(json_ld, F_JSONLD),
        pad_or_truncate(body_line, F_BODY),
    );

    debug_assert_eq!(record.len(), RECORD_LEN);

    out.write_all(record.as_bytes())
        .map_err(|e| e.to_string())?;
    out.write_all(b"\n").map_err(|e| e.to_string())?;

    Ok(())
}

/// Pad with spaces or truncate to exact width
fn pad_or_truncate(s: &str, width: usize) -> String {
    // Work with ASCII-safe bytes - replace non-ASCII with '?'
    let safe: String = s
        .chars()
        .map(|c| if c.is_ascii() { c } else { '?' })
        .collect();

    if safe.len() >= width {
        safe[..width].to_string()
    } else {
        format!("{:<width$}", safe, width = width)
    }
}

fn parse_date(s: &str) -> Result<NaiveDate, String> {
    let formats = ["%Y-%m-%d", "%Y/%m/%d", "%Y%m%d", "%B %d, %Y", "%d %B %Y"];
    for fmt in &formats {
        if let Ok(d) = NaiveDate::parse_from_str(s.trim(), fmt) {
            return Ok(d);
        }
    }
    Err(format!("Cannot parse date: '{}'", s))
}

fn slugify(title: &str) -> String {
    title
        .to_lowercase()
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() {
                c
            } else {
                '-'
            }
        })
        .collect::<String>()
        .split('-')
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

fn trim_to_word_boundary(s: &str, max_len: usize) -> String {
    if s.len() <= max_len {
        return s.to_string();
    }
    let truncated = &s[..max_len];
    if let Some(last_space) = truncated.rfind(' ') {
        truncated[..last_space].to_string()
    } else {
        truncated.to_string()
    }
}

fn markdown_to_plain(md: &str) -> String {
    let parser = MdParser::new(md);
    let mut text = String::new();
    for event in parser {
        if let Event::Text(t) = event {
            text.push_str(&t);
            text.push(' ');
        }
    }
    text.trim().to_string()
}

fn markdown_to_html(md: &str) -> String {
    let parser = MdParser::new(md);
    let mut html = String::new();
    let mut in_paragraph = false;

    for event in parser {
        match event {
            Event::Start(Tag::Paragraph) => {
                html.push_str("<p>");
                in_paragraph = true;
            }
            Event::End(TagEnd::Paragraph) => {
                html.push_str("</p>");
                in_paragraph = false;
            }
            Event::Start(Tag::Heading { level, .. }) => {
                html.push_str(&format!("<h{}>", level as u8));
            }
            Event::End(TagEnd::Heading(level)) => {
                html.push_str(&format!("</h{}>", level as u8));
            }
            Event::Start(Tag::Emphasis) => html.push_str("<em>"),
            Event::End(TagEnd::Emphasis) => html.push_str("</em>"),
            Event::Start(Tag::Strong) => html.push_str("<strong>"),
            Event::End(TagEnd::Strong) => html.push_str("</strong>"),
            Event::Start(Tag::Link { dest_url, .. }) => {
                html.push_str(&format!("<a href=\"{}\">", dest_url));
            }
            Event::End(TagEnd::Link) => html.push_str("</a>"),
            Event::Start(Tag::List(None)) => html.push_str("<ul>"),
            Event::End(TagEnd::List(false)) => html.push_str("</ul>"),
            Event::Start(Tag::List(Some(_))) => html.push_str("<ol>"),
            Event::End(TagEnd::List(true)) => html.push_str("</ol>"),
            Event::Start(Tag::Item) => html.push_str("<li>"),
            Event::End(TagEnd::Item) => html.push_str("</li>"),
            Event::Start(Tag::BlockQuote) => html.push_str("<blockquote>"),
            Event::End(TagEnd::BlockQuote) => html.push_str("</blockquote>"),
            Event::Start(Tag::CodeBlock(_)) => html.push_str("<pre><code>"),
            Event::End(TagEnd::CodeBlock) => html.push_str("</code></pre>"),
            Event::Code(code) => {
                html.push_str(&format!("<code>{}</code>", code));
            }
            Event::Text(text) => {
                html.push_str(&text);
            }
            Event::SoftBreak | Event::HardBreak => {
                if in_paragraph {
                    html.push(' ');
                }
            }
            _ => {}
        }
    }
    html
}

/// Wrap an HTML string into lines of at most `max_len` bytes,
/// trying to break at tag boundaries or spaces.
fn wrap_lines(html: &str, max_len: usize) -> Vec<String> {
    let mut lines = Vec::new();
    let mut current = String::new();

    let mut chars = html.chars().peekable();

    while let Some(&c) = chars.peek() {
        if c == '<' {
            // Read the full tag
            let mut tag = String::new();
            while let Some(&tc) = chars.peek() {
                tag.push(tc);
                chars.next();
                if tc == '>' {
                    break;
                }
            }

            if current.len() + tag.len() > max_len && !current.is_empty() {
                lines.push(current.clone());
                current.clear();
            }
            current.push_str(&tag);
        } else {
            chars.next();
            current.push(c);

            if current.len() >= max_len {
                // Try to break at last space
                if let Some(pos) = current[..max_len].rfind(' ') {
                    let (left, right) = current.split_at(pos + 1);
                    lines.push(left.trim_end().to_string());
                    current = right.to_string();
                } else {
                    lines.push(current[..max_len].to_string());
                    current = current[max_len..].to_string();
                }
            }
        }
    }

    if !current.is_empty() {
        lines.push(current);
    }

    lines
}

fn build_json_ld(
    title: &str,
    description: &str,
    author: &str,
    date_iso: &str,
    canonical: &str,
) -> String {
    let obj = serde_json::json!({
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        "headline": title,
        "description": description,
        "author": {
            "@type": "Person",
            "name": author
        },
        "datePublished": date_iso,
        "url": canonical
    });

    serde_json::to_string(&obj).unwrap_or_default()
}
