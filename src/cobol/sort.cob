       IDENTIFICATION DIVISION.
       PROGRAM-ID. COBLOG-SORT.
      * ============================================================
      * COBLOG Multi-Key Sort Driver
      * Reads fixed-width records from stdin, sorts by tag then date,
      * writes sorted records to stdout.
      * Sort order is configurable via --by= command line argument.
      * ============================================================

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO KEYBOARD
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-INPUT-STATUS.
           SELECT OUTPUT-FILE ASSIGN TO DISPLAY
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-OUTPUT-STATUS.
           SELECT SORT-FILE ASSIGN TO "SORT-WORK".

       DATA DIVISION.
       FILE SECTION.

       FD INPUT-FILE.
       01 INPUT-RECORD         PIC X(1538).

       FD OUTPUT-FILE.
       01 OUTPUT-RECORD        PIC X(1538).

       SD SORT-FILE.
       01 SORT-RECORD.
           05 SORT-DATE        PIC X(8).
           05 SORT-SLUG        PIC X(60).
           05 SORT-TITLE       PIC X(120).
           05 SORT-AUTHOR      PIC X(40).
           05 SORT-TAG         PIC X(30).
           05 SORT-REST        PIC X(1280).

       WORKING-STORAGE SECTION.
       01 WS-INPUT-STATUS      PIC XX VALUE SPACES.
       01 WS-OUTPUT-STATUS     PIC XX VALUE SPACES.
       01 WS-SORT-MODE         PIC X(20) VALUE SPACES.
       01 WS-ARGS              PIC X(256) VALUE SPACES.

       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-ARGS FROM COMMAND-LINE

      * Parse sort mode from command line
           IF WS-ARGS = SPACES
               MOVE "tag-date" TO WS-SORT-MODE
           ELSE
               INSPECT WS-ARGS REPLACING ALL
                   "--by=" BY SPACES
               MOVE FUNCTION TRIM(WS-ARGS) TO WS-SORT-MODE
           END-IF

           EVALUATE WS-SORT-MODE
               WHEN "tag-date"
                   SORT SORT-FILE
                       ON ASCENDING KEY SORT-TAG
                       ON ASCENDING KEY SORT-DATE
                       ON ASCENDING KEY SORT-SLUG
                       INPUT PROCEDURE IS READ-INPUT
                       OUTPUT PROCEDURE IS WRITE-OUTPUT
               WHEN "date-desc"
                   SORT SORT-FILE
                       ON DESCENDING KEY SORT-DATE
                       ON ASCENDING KEY SORT-SLUG
                       INPUT PROCEDURE IS READ-INPUT
                       OUTPUT PROCEDURE IS WRITE-OUTPUT
               WHEN "date-asc"
                   SORT SORT-FILE
                       ON ASCENDING KEY SORT-DATE
                       ON ASCENDING KEY SORT-SLUG
                       INPUT PROCEDURE IS READ-INPUT
                       OUTPUT PROCEDURE IS WRITE-OUTPUT
               WHEN "author-date"
                   SORT SORT-FILE
                       ON ASCENDING KEY SORT-AUTHOR
                       ON ASCENDING KEY SORT-DATE
                       ON ASCENDING KEY SORT-SLUG
                       INPUT PROCEDURE IS READ-INPUT
                       OUTPUT PROCEDURE IS WRITE-OUTPUT
               WHEN OTHER
                   DISPLAY "Unknown sort mode: " WS-SORT-MODE
                   SORT SORT-FILE
                       ON ASCENDING KEY SORT-TAG
                       ON ASCENDING KEY SORT-DATE
                       ON ASCENDING KEY SORT-SLUG
                       INPUT PROCEDURE IS READ-INPUT
                       OUTPUT PROCEDURE IS WRITE-OUTPUT
           END-EVALUATE

           STOP RUN.

       READ-INPUT SECTION.
       READ-INPUT-PARA.
           OPEN INPUT INPUT-FILE
           IF WS-INPUT-STATUS NOT = "00"
               DISPLAY "Error opening input: " WS-INPUT-STATUS
               STOP RUN
           END-IF

           PERFORM UNTIL 1 = 0
               READ INPUT-FILE INTO SORT-RECORD
                   AT END
                       EXIT PERFORM
                   NOT AT END
                       RELEASE SORT-RECORD
               END-READ
           END-PERFORM

           CLOSE INPUT-FILE.

       WRITE-OUTPUT SECTION.
       WRITE-OUTPUT-PARA.
           OPEN OUTPUT OUTPUT-FILE
           IF WS-OUTPUT-STATUS NOT = "00"
               DISPLAY "Error opening output: " WS-OUTPUT-STATUS
               STOP RUN
           END-IF

           PERFORM UNTIL 1 = 0
               RETURN SORT-FILE INTO OUTPUT-RECORD
                   AT END
                       EXIT PERFORM
                   NOT AT END
                       WRITE OUTPUT-RECORD
               END-RETURN
           END-PERFORM

           CLOSE OUTPUT-FILE.
