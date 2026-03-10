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

      * Index entry buffer (max 200 posts)
       01 WS-INDEX-TABLE.
           05 WS-INDEX-ENTRY OCCURS 200 TIMES.
               10 WS-IDX-SLUG     PIC X(60).
               10 WS-IDX-TITLE    PIC X(120).
               10 WS-IDX-DATE     PIC X(10).
               10 WS-IDX-AUTHOR   PIC X(40).
               10 WS-IDX-TAG      PIC X(30).
               10 WS-IDX-DESC     PIC X(160).
       01 WS-IDX-I              PIC 999 VALUE 0.

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

           CLOSE INPUT-FILE

      * Now generate the index page from buffered entries
           IF WS-POST-COUNT > 0
               PERFORM GENERATE-INDEX-PAGE
           END-IF

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
      * Buffer index entry for later
               PERFORM BUFFER-INDEX-ENTRY
               MOVE WS-TRIMMED-SLUG TO WS-CURRENT-SLUG
           END-IF

      * Write body line to post page
           IF WS-TRIMMED-BODY NOT = SPACES
               MOVE WS-TRIMMED-BODY TO OUTPUT-RECORD
               WRITE OUTPUT-RECORD
           END-IF.

       BUFFER-INDEX-ENTRY.
      * Store index data in table for deferred index generation
           ADD 1 TO WS-POST-COUNT
           IF WS-POST-COUNT <= 200
               MOVE WS-TRIMMED-SLUG TO
                   WS-IDX-SLUG(WS-POST-COUNT)
               MOVE WS-TRIMMED-TITLE TO
                   WS-IDX-TITLE(WS-POST-COUNT)
               MOVE WS-DISP-DATE TO
                   WS-IDX-DATE(WS-POST-COUNT)
               MOVE WS-TRIMMED-AUTHOR TO
                   WS-IDX-AUTHOR(WS-POST-COUNT)
               MOVE WS-TRIMMED-TAG TO
                   WS-IDX-TAG(WS-POST-COUNT)
               MOVE WS-TRIMMED-DESC TO
                   WS-IDX-DESC(WS-POST-COUNT)
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

       GENERATE-INDEX-PAGE.
      * Write the index page after all post pages are closed
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
           MOVE "<title>COBLOG</title>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           STRING "<meta name='description' content="
               "'A blog powered by COBOL Report Writer'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           STRING "<link rel='alternate' type='application/rss+xml'"
               " title='COBLOG RSS' href='/feed.xml'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           STRING "<link rel='stylesheet' href='/style.css'>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "</head>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<body>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<header>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<nav><a href='/'>COBLOG</a></nav>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "</header>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           MOVE "<main>" TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD

      * Write buffered index entries with tag control breaks
           MOVE SPACES TO WS-CURRENT-TAG
           MOVE 0 TO WS-IN-SECTION
           PERFORM VARYING WS-IDX-I FROM 1 BY 1
               UNTIL WS-IDX-I > WS-POST-COUNT
               PERFORM WRITE-BUFFERED-INDEX-ENTRY
           END-PERFORM

      * Close last tag section if open
           IF WS-IN-SECTION = 1
               MOVE "</section>" TO OUTPUT-RECORD
               WRITE OUTPUT-RECORD
               MOVE 0 TO WS-IN-SECTION
           END-IF

      * Close index page
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
           MOVE 0 TO WS-INDEX-OPEN.

       WRITE-BUFFERED-INDEX-ENTRY.
      * Control break on tag
           IF WS-IDX-TAG(WS-IDX-I) NOT = WS-CURRENT-TAG
               IF WS-IN-SECTION = 1
                   MOVE "</section>" TO OUTPUT-RECORD
                   WRITE OUTPUT-RECORD
               END-IF
               STRING "<section class='tag-group'>"
                   "<h2>"
                   FUNCTION TRIM(WS-IDX-TAG(WS-IDX-I))
                   "</h2>"
                   DELIMITED SIZE INTO WS-LINE
               MOVE WS-LINE TO OUTPUT-RECORD
               WRITE OUTPUT-RECORD
               MOVE 1 TO WS-IN-SECTION
               MOVE WS-IDX-TAG(WS-IDX-I) TO WS-CURRENT-TAG
           END-IF

      * Write index entry
           STRING "<article class='post-preview'>"
               "<h3><a href='/"
               FUNCTION TRIM(WS-IDX-SLUG(WS-IDX-I))
               "/'>"
               FUNCTION TRIM(WS-IDX-TITLE(WS-IDX-I))
               "</a></h3>"
               "<div class='meta'><time>"
               FUNCTION TRIM(WS-IDX-DATE(WS-IDX-I))
               "</time> &middot; "
               FUNCTION TRIM(WS-IDX-AUTHOR(WS-IDX-I))
               "</div>"
               "<p>"
               FUNCTION TRIM(WS-IDX-DESC(WS-IDX-I))
               "</p></article>"
               DELIMITED SIZE INTO WS-LINE
           MOVE WS-LINE TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD.
