       IDENTIFICATION DIVISION.
       PROGRAM-ID. COBLOG-RSS.
      * ============================================================
      * COBLOG RSS 2.0 Feed Generator
      * Reads sorted fixed-width records, emits RSS XML to stdout.
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
       01 WS-IN-ITEM           PIC 9  VALUE 0.
       01 WS-ITEM-COUNT        PIC 999 VALUE 0.
       01 WS-MAX-ITEMS         PIC 999 VALUE 20.

      * Trimmed fields
       01 WS-TRIMMED-TITLE     PIC X(120) VALUE SPACES.
       01 WS-TRIMMED-DESC      PIC X(160) VALUE SPACES.
       01 WS-TRIMMED-CANONICAL PIC X(120) VALUE SPACES.
       01 WS-TRIMMED-SLUG      PIC X(60) VALUE SPACES.
       01 WS-TRIMMED-AUTHOR    PIC X(40) VALUE SPACES.
       01 WS-TRIMMED-DATE      PIC X(8)  VALUE SPACES.

      * RFC 822 date parts
       01 WS-YEAR              PIC X(4) VALUE SPACES.
       01 WS-MONTH             PIC X(2) VALUE SPACES.
       01 WS-DAY               PIC X(2) VALUE SPACES.
       01 WS-MONTH-NAME        PIC X(3) VALUE SPACES.
       01 WS-RFC-DATE          PIC X(40) VALUE SPACES.
       01 WS-MONTH-NUM         PIC 99 VALUE 0.

      * Output buffer
       01 WS-LINE              PIC X(2048) VALUE SPACES.

       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN INPUT INPUT-FILE
           IF WS-INPUT-STATUS NOT = "00"
               DISPLAY "Error opening input: " WS-INPUT-STATUS
               STOP RUN
           END-IF

           PERFORM READ-AND-EMIT UNTIL WS-EOF = 1

      * Close last item if open
           IF WS-IN-ITEM = 1
               DISPLAY "    </item>"
           END-IF

      * Report footing - close channel
           IF WS-HEADER-WRITTEN = 1
               DISPLAY "  </channel>"
               DISPLAY "</rss>"
           END-IF

           CLOSE INPUT-FILE
           STOP RUN.

       READ-AND-EMIT.
           READ INPUT-FILE INTO INPUT-RECORD
               AT END
                   MOVE 1 TO WS-EOF
               NOT AT END
                   PERFORM PROCESS-RSS-RECORD
           END-READ.

       PROCESS-RSS-RECORD.
      * Only process first record per slug (control break)
           MOVE FUNCTION TRIM(POST-SLUG) TO WS-TRIMMED-SLUG

           IF WS-TRIMMED-SLUG = WS-CURRENT-SLUG
               EXIT PARAGRAPH
           END-IF

      * Limit items
           IF WS-ITEM-COUNT >= WS-MAX-ITEMS
               MOVE 1 TO WS-EOF
               EXIT PARAGRAPH
           END-IF

      * Trim fields
           MOVE FUNCTION TRIM(POST-TITLE) TO WS-TRIMMED-TITLE
           MOVE FUNCTION TRIM(POST-DESC) TO WS-TRIMMED-DESC
           MOVE FUNCTION TRIM(POST-CANONICAL)
               TO WS-TRIMMED-CANONICAL
           MOVE FUNCTION TRIM(POST-AUTHOR) TO WS-TRIMMED-AUTHOR
           MOVE POST-DATE TO WS-TRIMMED-DATE

      * Report Heading - channel header (once)
           IF WS-HEADER-WRITTEN = 0
               DISPLAY
                   "<?xml version='1.0' encoding='UTF-8'?>"
               DISPLAY
                   "<rss version='2.0'>"
               DISPLAY "  <channel>"
               DISPLAY "    <title>COBLOG</title>"
               DISPLAY
                   "    <description>"
                   "A blog powered by COBOL Report Writer"
                   "</description>"
               DISPLAY "    <language>en-us</language>"
               MOVE 1 TO WS-HEADER-WRITTEN
           END-IF

      * Close previous item
           IF WS-IN-ITEM = 1
               DISPLAY "    </item>"
           END-IF

      * Format RFC 822 date
           PERFORM FORMAT-RFC822-DATE

      * Emit item (Detail equivalent)
           DISPLAY "    <item>"
           STRING "      <title>"
               FUNCTION TRIM(WS-TRIMMED-TITLE)
               "</title>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)
           STRING "      <link>"
               FUNCTION TRIM(WS-TRIMMED-CANONICAL)
               "</link>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)
           STRING "      <description>"
               FUNCTION TRIM(WS-TRIMMED-DESC)
               "</description>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)
           STRING "      <author>"
               FUNCTION TRIM(WS-TRIMMED-AUTHOR)
               "</author>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)
           STRING "      <guid>"
               FUNCTION TRIM(WS-TRIMMED-CANONICAL)
               "</guid>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)
           STRING "      <pubDate>"
               FUNCTION TRIM(WS-RFC-DATE)
               "</pubDate>"
               DELIMITED SIZE INTO WS-LINE
           DISPLAY FUNCTION TRIM(WS-LINE)

           MOVE 1 TO WS-IN-ITEM
           ADD 1 TO WS-ITEM-COUNT
           MOVE WS-TRIMMED-SLUG TO WS-CURRENT-SLUG.

       FORMAT-RFC822-DATE.
      * Convert YYYYMMDD to RFC 822: DD Mon YYYY 00:00:00 GMT
           MOVE WS-TRIMMED-DATE(1:4) TO WS-YEAR
           MOVE WS-TRIMMED-DATE(5:2) TO WS-MONTH
           MOVE WS-TRIMMED-DATE(7:2) TO WS-DAY

           MOVE FUNCTION NUMVAL(WS-MONTH) TO WS-MONTH-NUM

           EVALUATE WS-MONTH-NUM
               WHEN 1  MOVE "Jan" TO WS-MONTH-NAME
               WHEN 2  MOVE "Feb" TO WS-MONTH-NAME
               WHEN 3  MOVE "Mar" TO WS-MONTH-NAME
               WHEN 4  MOVE "Apr" TO WS-MONTH-NAME
               WHEN 5  MOVE "May" TO WS-MONTH-NAME
               WHEN 6  MOVE "Jun" TO WS-MONTH-NAME
               WHEN 7  MOVE "Jul" TO WS-MONTH-NAME
               WHEN 8  MOVE "Aug" TO WS-MONTH-NAME
               WHEN 9  MOVE "Sep" TO WS-MONTH-NAME
               WHEN 10 MOVE "Oct" TO WS-MONTH-NAME
               WHEN 11 MOVE "Nov" TO WS-MONTH-NAME
               WHEN 12 MOVE "Dec" TO WS-MONTH-NAME
               WHEN OTHER MOVE "Jan" TO WS-MONTH-NAME
           END-EVALUATE

           STRING WS-DAY " "
               WS-MONTH-NAME " "
               WS-YEAR " 00:00:00 GMT"
               DELIMITED SIZE INTO WS-RFC-DATE.
