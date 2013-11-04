;;; -*- Mode:Emacs-Lisp -*-

;;; This file contains the migration functions for the Insidious Big
;;; Brother Database (aka BBDB), copyright (c) 1991, 1992, 1993, 1994
;;; Jamie Zawinski <jwz@netscape.com>.  See the file bbdb.texinfo for
;;; documentation.
;;;
;;; The Insidious Big Brother Database is free software; you can redistribute
;;; it and/or modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2, or (at your
;;; option) any later version.
;;;
;;; BBDB is distributed in the hope that it will be useful, but WITHOUT ANY
;;; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;;; details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
;;;

;;
;; $Id: bbdb-migrate.el,v 1.8 2005/07/24 15:22:58 waider Exp $
;;
;; $Log: bbdb-migrate.el,v $
;; Revision 1.8  2005/07/24 15:22:58  waider
;; sync with Sourceforge CVS
;;
;; Revision 1.20  2004/03/22 15:55:03  waider
;; * Minor docstring fix (Stefan Monnier)
;; * Catch error if attempting to kill only window in frame (Stefan Monnier)
;;
;; Revision 1.19  2002/08/19 22:49:12  waider
;; Jim Blandy's fix for migrating notes.
;;
;; Revision 1.18  2002/05/12 22:17:03  waider
;; Dave Love's big patch. See ChangeLog for full details.
;;
;; Revision 1.17  2001/05/17 17:15:31  fenk
;; (bbdb-unmigrate-zip-codes-to-strings): Fixed the faulty use of let instead of let*.
;;
;; Revision 1.16  2000/11/27 12:59:53  waider
;; Alex's zipcode changes. WARNING: New database format.
;;
;; Revision 1.15  2000/08/05 15:38:04  waider
;; When converting the streets to a list, delete "nil" as well as "".
;;
;; Revision 1.14  2000/07/11 21:28:44  sds
;; (bbdb-migrate-record-lambda): `mapcar', not `mapc' here!
;;
;; Revision 1.13  2000/07/10 17:00:12  sds
;; revert the last patch (`mapc' is more efficient than `mapcar')
;;
;; Revision 1.12  2000/07/09 09:20:11  waider
;; GNUmacs doesn't have "mapc".
;;
;; Revision 1.11  2000/07/05 21:43:35  sds
;; rewrote migration in a modular way
;;
;; Revision 1.10  2000/06/30 19:12:36  sds
;; (bbdb-migrate): re-wrote using `mapcar' instead of `append'
;; this is linear instead of quadratic and avoids much consing
;;
;; Revision 1.9  2000/05/29 22:47:50  waider
;; *** empty log message ***
;;
;; Revision 1.8  2000/04/17 08:30:47  waider
;; omitted bracket on unmigrate for v5->v4
;;
;; Revision 1.7  2000/04/16 04:00:54  waider
;; * Added 5->4 unmigration
;;
;; Revision 1.6  2000/04/15 14:57:38  waider
;; * Fixed misplaced bracket in street migration code.
;;
;; Revision 1.5  2000/04/12 23:57:16  waider
;; * Added v5 migration. NB no back-migration yet.
;;
;; Revision 1.4  2000/04/05 16:45:07  bbdb-writer
;; * Added Alex's BBDB v4 format migration (country field)
;;
;; Revision 1.3  1998/10/10 18:47:21  simmonmt
;; From slbaur: Don't pass an integer to concat.
;; Format dates with number format - not string - so we get leading
;; zeros.
;;
;; Revision 1.2  1998/04/11 07:19:19  simmonmt
;; Colin Rafferty's patch adding autoload cookies back
;;
;; Revision 1.1  1998/01/06 06:06:06  simmonmt
;; Initial revision
;;
;;

(require 'bbdb)

;;; Migrating the BBDB

;; Features that have changed in the various database revs.  Format:
;;    ((VERSION . DIFFERENCES) ... )
(defconst bbdb-migration-features
  '((3 . "* Date format for `creation-date' and `timestamp' has changed,
  from \"dd mmm yy\" (ex: 25 Sep 97) to \"yyyy-mm-dd\" (ex: 1997-09-25).")
    (4 . "* Country field added.")
    (5 . "* More flexible street address.")
    (6 . "* Zip codes are stored as plain strings.")))

;;;###autoload
(defun bbdb-migration-query (ondisk)
  "Ask if the database is to be migrated.
ONDISK is the version number of the database as currently stored on
disk.  Returns the version for the saved database."
  (save-excursion
    (let ((wc (current-window-configuration))
      (buf (get-buffer-create "*BBDB Migration Info*"))
      (newfeatures bbdb-migration-features)
      (first t)
      win update)
      (set-buffer buf)
      (erase-buffer)
      (goto-char (point-min))
      (insert-string (format "BBDB new data version notice:
=============================

Your BBDB data is stored in an older format (version %d).  At this point,
you have the option of either upgrading or continuing to save your data
in your current format.  Please note that if you elect the latter option,
any changes made to your data using features intended for the newer
versions will be lost.  For your convenience, a list of file format
changes introduced after version %d is shown below:\n\n" ondisk ondisk))
      (while newfeatures
    (if (> (caar newfeatures) ondisk)
      (insert-string (concat (if first (setq first nil) "\n\n")
                 "New features in database version "
                 (format "%d" (caar newfeatures))
                 ":\n\n" (cdar newfeatures))))
    (setq newfeatures (cdr newfeatures)))
      (setq win (display-buffer buf))
      (shrink-window-if-larger-than-buffer win)
      (setq update
        (y-or-n-p (concat "Upgrade BBDB to version "
                  (format "%d" bbdb-file-format)
                  "? ")))
      (condition-case nil
          (delete-window win)
        ;; The window might be the only one on its frame.  Hopefully, it's
        ;; a dedicated window and the kill-buffer below will DTRT.
        (error nil))
      (kill-buffer buf)
      (set-window-configuration wc)
      (if update bbdb-file-format ondisk))))

;;;###autoload
(defun bbdb-migrate (records)
  "Migrate the BBDB from the version on disk (the car of
`bbdb-file-format-migration') to the current version (in
`bbdb-file-format')."
  (bbdb-mapc (bbdb-migrate-versions-lambda (car bbdb-file-format-migration))
         records)
  records)

;;;###autoload
(defun bbdb-unmigrate-record (record)
  "Reverse-migrate a single record from the current version (in
`bbdb-file-format') to the version to be saved (the cdr of
`bbdb-file-format-migration')."
  (funcall (bbdb-migrate-versions-lambda bbdb-file-format
                                         (car bbdb-file-format-migration))
           record)
  record)

(defconst bbdb-migration-spec
  '((2 (bbdb-record-raw-notes bbdb-record-set-raw-notes
        bbdb-migrate-change-dates))
    (3 (bbdb-record-addresses bbdb-record-set-addresses
        bbdb-migrate-add-country-field))
    (4 (bbdb-record-addresses bbdb-record-set-addresses
        bbdb-migrate-streets-to-list))
    (5 (bbdb-record-addresses bbdb-record-set-addresses
        bbdb-migrate-zip-codes-to-strings)))
  "The alist of (version . migration-spec-list).
See `bbdb-migrate-record-lambda' for details.")

(defconst bbdb-unmigration-spec
  '((2 (bbdb-record-raw-notes bbdb-record-set-raw-notes
        bbdb-unmigrate-change-dates))
    (3 (bbdb-record-addresses bbdb-record-set-addresses
        bbdb-unmigrate-add-country-field))
    (4 (bbdb-record-addresses bbdb-record-set-addresses
        bbdb-unmigrate-streets-to-list))
    (5 (bbdb-record-addresses bbdb-record-set-addresses
        bbdb-unmigrate-zip-codes-to-strings)))
  "The alist of (version . migration-spec-list).
See `bbdb-migrate-record-lambda' for details.")

(defun bbdb-migrate-record-lambda (changes)
  "Return a function which will migrate a single record.
CHANGES is a `migration-spec-list' containing entries of the form

        (GET SET FUNCTION)

where GET is the function to be used to retrieve the field to be
modified, and SET is the function to be used to set the field to be
modified.  FUNCTION will be applied to the result of GET, and its
results will be saved with SET."
  (byte-compile `(lambda (rec)
                  ,@(mapcar (lambda (ch)
                              `(,(cadr ch) rec
                                (,(car (cddr ch))
                                 (,(car ch) rec))))
                            changes)
                  rec)))

(defun bbdb-migrate-versions-lambda (v0 &optional v1)
  "Return the function to migrate from V0 to V1.
V1 defaults to `bbdb-file-format'."
  (setq v1 (or v1 bbdb-file-format))
  (let ((vv v0) spec)
    (while (/= vv v1)
      (setq spec (append spec (cdr (assoc vv bbdb-migration-spec)))
            vv (if (< v0 v1) (1+ vv) (1- vv))))
    (bbdb-migrate-record-lambda spec)))

(defun bbdb-migrate-zip-codes-to-strings (addrs)
  "Make all zip codes plain strings.
This uses the code that used to be in bbdb-address-zip-string."
  ;; apply the function to all addresses in the list and return a
  ;; modified list of addresses
  (mapcar (lambda (addr)
            (let ((zip (if (stringp (bbdb-address-zip addr))
                           (bbdb-address-zip addr)
                         ;; if not a string, make it a string...
                         (if (consp (bbdb-address-zip addr))
                             ;; if a cons cell with two strings
                             (if (and (stringp (car (bbdb-address-zip addr)))
                                      (stringp (car (cdr (bbdb-address-zip addr)))))
                                 ;; if the second string starts with 4 digits
                                 (if (string-match "^[0-9][0-9][0-9][0-9]"
                                                   (car (cdr (bbdb-address-zip addr))))
                                     (concat (car (bbdb-address-zip addr))
                                             "-"
                                             (car (cdr (bbdb-address-zip addr))))
                                   ;; if ("abc" "efg")
                                   (concat (car (bbdb-address-zip addr))
                                           " "
                                           (car (cdr (bbdb-address-zip addr)))))
                               ;; if ("SE" (123 45))
                               (if (and (stringp (nth 0 (bbdb-address-zip addr)))
                                        (consp (nth 1 (bbdb-address-zip addr)))
                                        (integerp (nth 0 (nth 1 (bbdb-address-zip addr))))
                                        (integerp (nth 1 (nth 1 (bbdb-address-zip addr)))))
                                   (format "%s-%d %d"
                                           (nth 0 (bbdb-address-zip addr))
                                           (nth 0 (nth 1 (bbdb-address-zip addr)))
                                           (nth 1 (nth 1 (bbdb-address-zip addr))))
                                 ;; if a cons cell with two numbers
                                 (if (and (integerp (car (bbdb-address-zip addr)))
                                          (integerp (car (cdr (bbdb-address-zip addr)))))
                                     (format "%05d-%04d" (car (bbdb-address-zip addr))
                                             (car (cdr (bbdb-address-zip addr))))
                                   ;; else a cons cell with a string an a number (possible error
                                   ;; if a cons cell with a number and a string -- note the
                                   ;; order!)
                                   (format "%s-%d" (car (bbdb-address-zip addr))
                                           (car (cdr (bbdb-address-zip addr)))))))
                           ;; if nil or zero
                           (if (or (eq 0 (bbdb-address-zip addr))
                                   (null (bbdb-address-zip addr)))
                               ""
                             ;; else a number, could be 3 to 5 digits (possible error: assuming
                             ;; no leading zeroes in zip codes)
                             (format "%d" (bbdb-address-zip addr)))))))
              (bbdb-address-set-zip addr zip))
            addr)
          addrs))

(defun bbdb-unmigrate-zip-codes-to-strings (addrs)
  "Make zip code string into zip code datastructures.
This uses the code that used to be in bbdb-parse-zip-string."
  ;; apply the function to all addresses in the list and return a
  ;; modified list of addresses
  (mapcar (lambda (addr)
            (let* ((string (bbdb-address-zip addr))
                  (zip (cond ((string-match "^[ \t\n]*$" string) 0)
                             ;; Matches 1 to 6 digits.
                             ((string-match "^[ \t\n]*[0-9][0-9]?[0-9]?[0-9]?[0-9]?[0-9]?[ \t\n]*$" string)
                              (string-to-int string))
                             ;; Matches 5 digits and 3 or 4 digits.
                             ((string-match "^[ \t\n]*\\([0-9][0-9][0-9][0-9][0-9]\\)[ \t\n]*-?[ \t\n]*\\([0-9][0-9][0-9][0-9]?\\)[ \t\n]*$" string)
                              (list (bbdb-subint string 1) (bbdb-subint string 2)))
                             ;; Match zip codes for Canada, UK, etc. (result is ("LL47" "U4B")).
                             ((string-match
                               "^[ \t\n]*\\([A-Za-z0-9]+\\)[ \t\n]+\\([A-Za-z0-9]+\\)[ \t\n]*$"
                               string)
                              (list (substring string (match-beginning 1) (match-end 1))
                                    (substring string (match-beginning 2) (match-end 2))))
                             ;; Match zip codes for continental Europe.  Examples "CH-8057"
                             ;; or "F - 83320" (result is ("CH" "8057") or ("F" "83320")).
                             ;; Support for "NL-2300RA" added at request from Carsten Dominik
                             ;; <dominik@astro.uva.nl>
                             ((string-match
                               "^[ \t\n]*\\([A-Z]+\\)[ \t\n]*-?[ \t\n]*\\([0-9]+ ?[A-Z]*\\)[ \t\n]*$" string)
                              (list (substring string (match-beginning 1) (match-end 1))
                                    (substring string (match-beginning 2) (match-end 2))))
                             ;; Match zip codes from Sweden where the five digits are grouped 3+2
                             ;; at the request from Mats Lofdahl <MLofdahl@solar.stanford.edu>.
                             ;; (result is ("SE" (133 36)))
                             ((string-match
                               "^[ \t\n]*\\([A-Z]+\\)[ \t\n]*-?[ \t\n]*\\([0-9]+\\)[ \t\n]+\\([0-9]+\\)[ \t\n]*$" string)
                              (list (substring string (match-beginning 1) (match-end 1))
                                    (list (bbdb-subint string 2)
                                          (bbdb-subint string 3)))))))
              (bbdb-address-set-zip addr zip)
              addr))
          addrs))

(defun bbdb-migrate-change-dates (rec)
  "Change date formats.
Formats are changed in timestamp and creation-date fields from
\"dd mmm yy\" to \"yyyy-mm-dd\".  Assumes the notes are passed in as an
argument."
  (unless (stringp rec)
    (bbdb-mapc (lambda (rr)
                 (when (memq (car rr) '(creation-date timestamp))
                   (bbdb-migrate-change-dates-change-field rr)))
               rec)
    rec))

(defun bbdb-migrate-change-dates-change-field (field)
  "Migrate the date field (the cdr of FIELD) from \"dd mmm yy\" to
\"yyyy-mm-dd\"."
  (let ((date (cdr field))
    parsed)
    ;; Verify and extract - this is fairly hideous
    (and (equal (setq parsed (timezone-parse-date (concat date " 00:00:00")))
        ["0" "0" "0" "0" nil])
     (equal (setq parsed (timezone-parse-date date))
        ["0" "0" "0" "0" nil])
     (cond ((string-match
         "^\\([0-9]\\{4\\}\\)[-/]\\([ 0-9]?[0-9]\\)[-/]\\([ 0-9]?[0-9]\\)" date)
        (setq parsed (vector (string-to-int (match-string 1 date))
                     (string-to-int (match-string 2 date))
                     (string-to-int (match-string 3 date))))
        ;; This should be fairly loud for GNU Emacs users
        (bbdb-warn "BBDB is treating %s field value %s as %s %d %d"
               (car field) (cdr field)
               (upcase-initials
                (downcase (car (rassoc (aref parsed 1)
                           timezone-months-assoc))))
               (aref parsed 2) (aref parsed 0)))
           ((string-match
         "^\\([ 0-9]?[0-9]\\)[-/]\\([ 0-9]?[0-9]\\)[-/]\\([0-9]\\{4\\}\\)" date)
        (setq parsed (vector (string-to-int (match-string 3 date))
                     (string-to-int (match-string 1 date))
                     (string-to-int (match-string 2 date))))
        ;; This should be fairly loud for GNU Emacs users
        (bbdb-warn "BBDB is treating %s field value %s as %s %d %d"
               (car field) (cdr field)
               (upcase-initials
                (downcase (car (rassoc (aref parsed 1)
                           timezone-months-assoc))))
               (aref parsed 2) (aref parsed 0)))
           (t ["0" "0" "0" "0" nil])))

    ;; I like numbers
    (and (stringp (aref parsed 0))
     (aset parsed 0 (string-to-int (aref parsed 0))))
    (and (stringp (aref parsed 1))
     (aset parsed 1 (string-to-int (aref parsed 1))))
    (and (stringp (aref parsed 2))
     (aset parsed 2 (string-to-int (aref parsed 2))))

    ;; Sanity check
    (cond ((and (< 0 (aref parsed 0))
        (< 0 (aref parsed 1)) (>= 12 (aref parsed 1))
        (< 0 (aref parsed 2))
        (>= (timezone-last-day-of-month (aref parsed 1)
                        (aref parsed 0))
            (aref parsed 2)))
       (setcdr field (format "%04d-%02d-%02d" (aref parsed 0)
                 (aref parsed 1) (aref parsed 2)))
       field)
      (t
       (error "BBDB cannot parse %s header value %S for upgrade"
          field date)))))

(defun bbdb-unmigrate-change-dates (rec)
  "Change date formats.
Formats are changed in timestamp and creation-date fields from
\"yyyy-mm-dd\" to \"dd mmm yy\".  Assumes the notes list is passed in
as an argument."
  (unless (stringp rec)
    (bbdb-mapc (lambda (rr)
                 (when (memq (car rr) '(creation-date timestamp))
                   (bbdb-unmigrate-change-dates-change-field rr)))
               rec)
    rec))

(defun bbdb-unmigrate-change-dates-change-field (field)
  "Unmigrate the date field (the cdr of FIELD) from \"yyyy-mm-dd\" to
\"yyyy-mm-dd\"."
  (cons (car field) (bbdb-time-convert (cdr field) "%e %b %y")))

(defun bbdb-migrate-add-country-field (addrl)
  "Add a country field to each address in the address list."
  (mapcar (lambda (addr) (vconcat addr [""])) addrl))

(defun bbdb-unmigrate-add-country-field (addrl)
  "Remove the country field from each address in the address list."
  ;; Some version 4 zip codes will be illegal version 3 (as used in
  ;; 2.00.06) zip codes.  This problem has not been solved.
  (mapcar (lambda (addr)
            (let* ((len (1- (length addr)))
                   (new-addr (make-vector len nil))
                   (ii 0))
              (while (< ii len)
                (aset new-addr ii (aref addr ii))
                (setq ii (1+ ii)))))
          addrl))

(defun bbdb-migrate-streets-to-list (addrl)
  "Convert the streets to a list."
  (mapcar (lambda (addr)
            (vector (aref addr 0) ; tag
                    (delete nil (delete "" ; nuke empties
                                        (list (aref addr 1) ; street1
                                              (aref addr 2) ; street2
                                              (aref addr 3))));street3
                    (aref addr 4) ; city
                    (aref addr 5) ; state
                    (aref addr 6) ; zip
                    (aref addr 7))) ; country
          addrl))

(defun bbdb-unmigrate-streets-to-list (addrl)
  "Convert the street list to the street[1-3] format."
  ;; Take all the old addresses, ie. the 5th field, and for each
  ;; address, render the third element (a list of streets) as three
  ;; vector elements (v4-style address). If there's more than 3
  ;; lines, everything remaining gets crammed into the third, using
  ;; commas to separate the bits. If there's less, fill out with nil.
  (mapcar (lambda (addr)
            (let ((streets (aref addr 1)))
              (vector (aref addr 0) ; tag
                      (or (nth 0 streets) "")
                      (or (nth 1 streets) "")
                      (mapconcat 'identity (cddr streets) ", ")
                      (aref addr 2) ; city
                      (aref addr 3) ; state
                      (aref addr 4) ; zip
                      (aref addr 5)))) ; country
          addrl))

;;;###autoload
(defun bbdb-migrate-rewrite-all (message-p &optional records)
  "Rewrite each and every record in the bbdb file; this is necessary if we
are updating an old file format.  MESSAGE-P says whether to sound off
for each record converted.  If RECORDS is non-nil, its value will be
used as the list of records to update."
  ;; RECORDS is used by the migration mechanism.  Since the migration
  ;; mechanism is called from within bbdb-records, if we called
  ;; bbdb-change-record, we'd recurse and die.  We're therefore left
  ;; with the slightly more palatable (but still not pretty) calling
  ;; of bbdb-overwrite-record-internal.
  (or records (setq records (bbdb-records)))
  (let ((i 0))
    (while records
      (bbdb-overwrite-record-internal (car records) nil)
      (if message-p (message "Updating %d: %s %s" (setq i (1+ i))
                 (bbdb-record-firstname (car records))
                 (bbdb-record-lastname  (car records))))
      (setq records (cdr records)))))
(defalias 'bbdb-dry-heaves 'bbdb-migrate-rewrite-all)

;;;###autoload
(defun bbdb-migrate-update-file-version (old new)
  "Change the `file-version' string from the OLD version to the NEW
version."
  (goto-char (point-min))
  (if (re-search-forward (format "^;;; file-version: %d$" old) nil t)
      (replace-match (format ";;; file-version: %d" new))
    (error (format "Can't find file-version string in %s buffer for v%d migration"
           bbdb-file new))))

(provide 'bbdb-migrate)
