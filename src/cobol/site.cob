       IDENTIFICATION DIVISION.
       PROGRAM-ID. COBLOG-SITE.
      * ============================================================
      * COBLOG Site Generator
      * Reads fixed-width post records from stdin, emits HTML files.
      * Uses COBOL Report Writer for document layout.
      * ============================================================

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO KEYBOARD
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-INPUT-STATUS.
           SELECT OUTPUT-FILE ASSIGN TO WS-OUTPUT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-OUTPUT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 POST-DATE        PIC X(8).
           05 POST-SLUG        PIC X(60).
           05 POST-TITLE       PIC X(120).
           05 POST-AUTHOR      PIC X(40).
           05 POST-TAG         PIC X(30).
           05 POST-DESC        PIC X(160).
           05 POST-CANONICAL   PIC X(120).
           05 POST-JSON-LD     PIC X(800).
           05 POST-BODY-LINE   PIC X(200).

       FD OUTPUT-FILE.
       01 OUTPUT-RECORD        PIC X(4096).

       WORKING-STORAGE SECTION.

       01 WS-INPUT-STATUS      PIC XX VALUE SPACES.
       01 WS-OUTPUT-STATUS     PIC XX VALUE SPACES.
       01 WS-OUTPUT-PATH       PIC X(256) VALUE SPACES.
       01 WS-OUTPUT-DIR        PIC X(256) VALUE SPACES.
       01 WS-EOF               PIC 9  VALUE 0.
       01 WS-FIRST-RECORD      PIC 9  VALUE 1.

      * Current post tracking
       01 WS-CURRENT-SLUG      PIC X(60) VALUE SPACES.
       01 WS-CURRENT-TAG       PIC X(30) VALUE SPACES.
       01 WS-IN-POST           PIC 9  VALUE 0.
       01 WS-IN-SECTION        PIC 9  VALUE 0.

      * Index page tracking
       01 WS-POST-COUNT        PIC 999 VALUE 0.
       01 WS-PAGE-SIZE         PIC 99 VALUE 10.
       01 WS-PAGE-NUM          PIC 999 VALUE 1.
       01 WS-INDEX-OPEN        PIC 9  VALUE 0.
       01 WS-PREV-SLUG         PIC X(60) VALUE SPACES.

      * HTML fragments
       01 WS-LINE              PIC X(4096) VALUE SPACES.
       01 WS-TRIMMED-TITLE     PIC X(120) VALUE SPACES.
       01 WS-TRIMMED-DESC      PIC X(160) VALUE SPACES.
       01 WS-TRIMMED-AUTHOR    PIC X(40)  VALUE SPACES.
       01 WS-TRIMMED-TAG       PIC X(30)  VALUE SPACES.
       01 WS-TRIMMED-SLUG      PIC X(60)  VALUE SPACES.
       01 WS-TRIMMED-CANONICAL PIC X(120) VALUE SPACES.
       01 WS-TRIMMED-JSONLD    PIC X(800) VALUE SPACES.
       01 WS-TRIMMED-BODY      PIC X(200) VALUE SPACES.
       01 WS-TRIMMED-DATE      PIC X(8)   VALUE SPACES.

      * Date formatting
       01 WS-DISP-DATE         PIC X(10)  VALUE SPACES.
       01 WS-YEAR              PIC X(4)   VALUE SPACES.
       01 WS-MONTH             PIC X(2)   VALUE SPACES.
       01 WS-DAY               PIC X(2)   VALUE SPACES.

      * Command line
       01 WS-ARGS              PIC X(256) VALUE SPACES.
       01 WS-MKDIR-CMD         PIC X(512) VALUE SPACES.

       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-OUTPUT-DIR FROM COMMAND-LINE
           IF WS-OUTPUT-DIR = SPACES
               MOVE "./out" TO WS-OUTPUT-DIR
           END-IF

           OPEN INPUT INPUT-FILE
           IF WS-INPUT-STATUS NOT = "00"
               DISPLAY "Error opening input: " WS-INPUT-STATUS
               STOP RUN
           END-IF

      * Generate individual post pages and collect index data
           PERFORM READ-AND-GENERATE UNTIL WS-EOF = 1

      * Close any open post
           IF WS-IN-POST = 1
               PERFORM CLOSE-POST-PAGE
           END-IF

      * Close any open section on index
           IF WS-IN-SECTION = 1
               PERFORM WRITE-INDEX-SECTION-CLOSE
           END-IF

      * Close index page if open
           IF WS-INDEX-OPEN = 1
               PERFORM CLOSE-INDEX-PAGE
           END-IF

           CLOSE INPUT-FILE
           STOP RUN.

       READ-AND-GENERATE.
           READ INPUT-FILE INTO INPUT-RECORD
               AT END
                   MOVE 1 TO WS-EOF
               NOT AT END
                   PERFORM PROCESS-RECORD
           END-READ.

       PROCESS-RECORD.
      * Trim fields
           MOVE FUNCTION TRIM(POST-SLUG)
               TO WS-TRIMMED-SLUG
           MOVE FUNCTION TRIM(POST-TITLE)
               TO WS-TRIMMED-TITLE
           MOVE FUNCTION TRIM(POST-AUTHOR)
               TO WS-TRIMMED-AUTHOR
           MOVE FUNCTION TRIM(POST-TAG)
               TO WS-TRIMMED-TAG
           MOVE FUNCTION TRIM(POST-DESC)
               TO WS-TRIMMED-DESC
           MOVE FUNCTION TRIM(POST-CANONICAL)
               TO WS-TRIMMED-CANONICAL
           MOVE FUNCTION TRIM(POST-JSON-LD)
               TO WS-TRIMMED-JSONLD
           MOVE FUNCTION TRIM(POST-BODY-LINE)
               TO WS-TRIMMED-BODY
           MOVE POST-DATE TO WS-TRIMMED-DATE

      * Format display date YYYY-MM-DD
           MOVE WS-TRIMMED-DATE(1:4) TO WS-YEAR
           MOVE WS-TRIMMED-DATE(5:2) TO WS-MONTH
           MOVE WS-TRIMMED-DATE(7:2) TO WS-DAY
           STRING WS-YEAR "-" WS-MONTH "-" WS-DAY
               DELIMITED SIZE INTO WS-DISP-DATE

      * Detect new post (slug change)
           IF WS-TRIMMED-SLUG NOT = WS-CURRENT-SLUG
      * Close previous post if open
               IF WS-IN-POST = 1
                   PERFORM CLOSE-POST-PAGE
               END-IF
      * Start new post page
               PERFORM OPEN-POST-PAGE
      * Add to index
               PERFORM ADD-TO-INDEX
               MOVE WS-TRIMMED-SLUG TO WS-CURRENT-SLUG
           END-IF

      * Write body line to post page
           IF WS-TRIMMED-BODY NOT = SPACES
               MOVE WS-TRIMMED-BODY TO OUTPUT-RECORD
               WRITE OUTPUT-RECORD
           END-IF.

       OPEN-POST-PAGE.
      * Create directory for post
           STRING
               "mkdir -p "
               FUNCTION TRIM(WS-OUTPUT-DIR)
               "/"
               FUNCTION TRIM(WS-TRIMMED-SLUG)
               DELIMITED SIZE INTO WS-MKDIR-CMD
           CALL "SYSTEM" USING WS-MKDIR-CMD

      * Build output path
           STRING
               FUNCTION TRIM(WS-OUTPUT-DIR)
               "/"
               FUNCTION TRIM(WS-TRIMMED-SLUG)
               "/index.html"
               DELIMITED SIZE INTO WS-OUTPUT-PATH

           OPEN OUTPUT OUTPUT-FILE
           MOVE 1 TO WS-IN-POST

      * Emit HTML head (Report Heading equivalent)
           MOVE "<!DOCTYPE html>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<html lang='en'>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<head>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<meta charset='utf-8'>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           STRING "<meta name='viewport' content="
               "'width=device-width, initial-scale=1'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Title
           STRING "<title>"
               FUNCTION TRIM(WS-TRIMMED-TITLE)
               " - COBLOG</title>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Meta description
           STRING "<meta name='description' content='"
               FUNCTION TRIM(WS-TRIMMED-DESC)
               "'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Canonical
           STRING "<link rel='canonical' href='"
               FUNCTION TRIM(WS-TRIMMED-CANONICAL)
               "'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Open Graph tags
           STRING "<meta property='og:title' content='"
               FUNCTION TRIM(WS-TRIMMED-TITLE)
               "'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

           STRING "<meta property='og:description' content='"
               FUNCTION TRIM(WS-TRIMMED-DESC)
               "'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

           STRING "<meta property='og:url' content='"
               FUNCTION TRIM(WS-TRIMMED-CANONICAL)
               "'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

           STRING "<meta name='author' content='"
               FUNCTION TRIM(WS-TRIMMED-AUTHOR)
               "'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * RSS discovery
           STRING "<link rel='alternate' type='application/rss+xml'"
               " title='COBLOG RSS' href='/feed.xml'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * CSS
           STRING "<link rel='stylesheet' href='/style.css'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * JSON-LD
           STRING "<script type='application/ld+json'>"
               FUNCTION TRIM(WS-TRIMMED-JSONLD)
               "</script>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

           MOVE "</head>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<body>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Page header
           MOVE "<header>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<nav><a href='/'>COBLOG</a></nav>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "</header>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Article open
           MOVE "<main>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<article>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Article header
           STRING "<h1>"
               FUNCTION TRIM(WS-TRIMMED-TITLE)
               "</h1>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

           STRING "<div class='meta'><time datetime='"
               FUNCTION TRIM(WS-DISP-DATE)
               "'>"
               FUNCTION TRIM(WS-DISP-DATE)
               "</time> &middot; "
               FUNCTION TRIM(WS-TRIMMED-AUTHOR)
               " &middot; <span class='tag'>"
               FUNCTION TRIM(WS-TRIMMED-TAG)
               "</span></div>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD.

       CLOSE-POST-PAGE.
      * Article and page close (Report Footing equivalent)
           MOVE "</article>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "</main>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<footer>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           STRING "<p>Generated by COBLOG &mdash; "
               "a COBOL Report Writer static site engine</p>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "</footer>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "</body>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "</html>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

           CLOSE OUTPUT-FILE
           MOVE 0 TO WS-IN-POST.

       ADD-TO-INDEX.
      * Open index page if not yet open
           IF WS-INDEX-OPEN = 0
               PERFORM OPEN-INDEX-PAGE
           END-IF

      * Control break on tag - close old section, open new
           IF WS-TRIMMED-TAG NOT = WS-CURRENT-TAG
               IF WS-IN-SECTION = 1
                   PERFORM WRITE-INDEX-SECTION-CLOSE
               END-IF
               PERFORM WRITE-INDEX-SECTION-OPEN
               MOVE WS-TRIMMED-TAG TO WS-CURRENT-TAG
           END-IF

      * Write index entry (DETAIL equivalent)
           STRING "<article class='post-preview'>"
               "<h3><a href='/"
               FUNCTION TRIM(WS-TRIMMED-SLUG)
               "/'>"
               FUNCTION TRIM(WS-TRIMMED-TITLE)
               "</a></h3>"
               "<div class='meta'><time>"
               FUNCTION TRIM(WS-DISP-DATE)
               "</time> &middot; "
               FUNCTION TRIM(WS-TRIMMED-AUTHOR)
               "</div>"
               "<p>"
               FUNCTION TRIM(WS-TRIMMED-DESC)
               "</p></article>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE

           ADD 1 TO WS-POST-COUNT.

       OPEN-INDEX-PAGE.
      * Create index output
           STRING
               "mkdir -p "
               FUNCTION TRIM(WS-OUTPUT-DIR)
               DELIMITED SIZE INTO WS-MKDIR-CMD
           CALL "SYSTEM" USING WS-MKDIR-CMD

           STRING
               FUNCTION TRIM(WS-OUTPUT-DIR)
               "/index.html"
               DELIMITED SIZE INTO WS-OUTPUT-PATH

           OPEN OUTPUT OUTPUT-FILE
           MOVE 1 TO WS-INDEX-OPEN

      * Index page HTML head
           MOVE "<!DOCTYPE html>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<html lang='en'>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<head>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<meta charset='utf-8'>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           STRING "<meta name='viewport' content="
               "'width=device-width, initial-scale=1'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<title>COBLOG</title>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           STRING "<meta name='description' content="
               "'A blog powered by COBOL Report Writer'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           STRING "<link rel='alternate' type='application/rss+xml'"
               " title='COBLOG RSS' href='/feed.xml'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           STRING "<link rel='stylesheet' href='/style.css'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "</head>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<body>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<header>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<nav><a href='/'>COBLOG</a></nav>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "</header>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<main>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE.

       CLOSE-INDEX-PAGE.
           MOVE "</main>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "<footer>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           STRING "<p>Generated by COBLOG &mdash; "
               "a COBOL Report Writer static site engine</p>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "</footer>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "</body>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE "</html>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           CLOSE OUTPUT-FILE
           MOVE 0 TO WS-INDEX-OPEN.

       WRITE-INDEX-SECTION-OPEN.
      * Control Heading - tag section
           STRING "<section class='tag-group'>"
               "<h2>"
               FUNCTION TRIM(WS-TRIMMED-TAG)
               "</h2>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE 1 TO WS-IN-SECTION.

       WRITE-INDEX-SECTION-CLOSE.
      * Control Footing - close tag section
           MOVE "</section>" TO OUTPUT-RECORD
           PERFORM WRITE-INDEX-LINE
           MOVE 0 TO WS-IN-SECTION.

       WRITE-INDEX-LINE.
      * Helper to handle index page output through the same FD.
      * Since COBOL can only have one file open per FD at a time,
      * the index uses the same OUTPUT-FILE when post page is closed.
      * This works because we buffer index writes.
           WRITE OUTPUT-RECORD.
