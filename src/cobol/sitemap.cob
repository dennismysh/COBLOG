       IDENTIFICATION DIVISION.
       PROGRAM-ID. COBLOG-SITEMAP.
      * ============================================================
      * COBLOG Sitemap Generator
      * Reads fixed-width records, emits sitemap.xml to stdout.
      * Control break on POST-SLUG ensures one <url> per post.
      * ============================================================

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO KEYBOARD
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-INPUT-STATUS.

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

       WORKING-STORAGE SECTION.
       01 WS-INPUT-STATUS      PIC XX VALUE SPACES.
       01 WS-EOF               PIC 9  VALUE 0.
       01 WS-CURRENT-SLUG      PIC X(60) VALUE SPACES.
       01 WS-HEADER-WRITTEN    PIC 9  VALUE 0.

      * Trimmed fields
       01 WS-TRIMMED-SLUG      PIC X(60) VALUE SPACES.
       01 WS-TRIMMED-CANONICAL PIC X(120) VALUE SPACES.
       01 WS-TRIMMED-DATE      PIC X(8) VALUE SPACES.

      * Date formatting
       01 WS-YEAR              PIC X(4) VALUE SPACES.
       01 WS-MONTH             PIC X(2) VALUE SPACES.
       01 WS-DAY               PIC X(2) VALUE SPACES.
       01 WS-ISO-DATE          PIC X(10) VALUE SPACES.

      * Output buffer
       01 WS-LINE              PIC X(512) VALUE SPACES.

       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN INPUT INPUT-FILE
           IF WS-INPUT-STATUS NOT = "00"
               DISPLAY "Error opening input: " WS-INPUT-STATUS
               STOP RUN
           END-IF

           PERFORM READ-AND-EMIT UNTIL WS-EOF = 1

      * Report Footing - close urlset
           IF WS-HEADER-WRITTEN = 1
               DISPLAY "</urlset>"
           END-IF

           CLOSE INPUT-FILE
           STOP RUN.

       READ-AND-EMIT.
           READ INPUT-FILE INTO INPUT-RECORD
               AT END
                   MOVE 1 TO WS-EOF
               NOT AT END
                   PERFORM PROCESS-SITEMAP-RECORD
           END-READ.

       PROCESS-SITEMAP-RECORD.
      * Control break on slug - one URL per post
           MOVE FUNCTION TRIM(POST-SLUG) TO WS-TRIMMED-SLUG

           IF WS-TRIMMED-SLUG = WS-CURRENT-SLUG
               EXIT PARAGRAPH
           END-IF

           MOVE FUNCTION TRIM(POST-CANONICAL)
               TO WS-TRIMMED-CANONICAL
           MOVE POST-DATE TO WS-TRIMMED-DATE

      * Report Heading - XML declaration and urlset open (once)
           IF WS-HEADER-WRITTEN = 0
               DISPLAY
                   "<?xml version='1.0' encoding='UTF-8'?>"
               DISPLAY
                   "<urlset xmlns="
                   "'http://www.sitemaps.org/schemas/sitemap/0.9'>"
               MOVE 1 TO WS-HEADER-WRITTEN
           END-IF

      * Format lastmod date as YYYY-MM-DD
           MOVE WS-TRIMMED-DATE(1:4) TO WS-YEAR
           MOVE WS-TRIMMED-DATE(5:2) TO WS-MONTH
           MOVE WS-TRIMMED-DATE(7:2) TO WS-DAY
           STRING WS-YEAR "-" WS-MONTH "-" WS-DAY
               DELIMITED SIZE INTO WS-ISO-DATE

      * Detail - emit one <url> block
           DISPLAY "  <url>"
           STRING "    <loc>"
               FUNCTION TRIM(WS-TRIMMED-CANONICAL)
               "</loc>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)
           STRING "    <lastmod>"
               FUNCTION TRIM(WS-ISO-DATE)
               "</lastmod>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)
           DISPLAY "  </url>"

           MOVE WS-TRIMMED-SLUG TO WS-CURRENT-SLUG.
