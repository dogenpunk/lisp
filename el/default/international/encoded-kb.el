;;; encoded-kb.el --- handler to input multibyte characters encoded somehow

;; Copyright (C) 1997  Free Software Foundation, Inc.
;; Copyright (C) 1995, 1997, 1998, 1999, 2000, 2001, 2004, 2005
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H14PRO021
;; Copyright (C) 2003
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H13PRO009

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Code:

;; Usually this map is empty (even if Encoded-kbd mode is on), but if
;; the keyboard coding system is iso-2022-based, it defines dummy key
;; bindings for ESC $ ..., etc. so that those bindings in
;; key-translation-map take effect.
(defconst encoded-kbd-mode-map (make-sparse-keymap)
  "Keymap for Encoded-kbd minor mode.")

;; Subsidiary keymaps for handling ISO2022 escape sequences.

(defvar encoded-kbd-iso2022-esc-map
  (let ((map (make-sparse-keymap)))
    (define-key map "$" 'encoded-kbd-iso2022-esc-dollar-prefix)
    (define-key map "(" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map ")" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "," 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "-" 'encoded-kbd-iso2022-designation-prefix)
    map)
  "Keymap for handling ESC code in Encoded-kbd mode.")
(fset 'encoded-kbd-iso2022-esc-prefix encoded-kbd-iso2022-esc-map)

(defvar encoded-kbd-iso2022-esc-dollar-map
  (let ((map (make-sparse-keymap)))
    (define-key map "(" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map ")" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "," 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "-" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "@" 'encoded-kbd-iso2022-designation)
    (define-key map "A" 'encoded-kbd-iso2022-designation)
    (define-key map "B" 'encoded-kbd-iso2022-designation)
    map)
  "Keymap for handling ESC $ sequence in Encoded-kbd mode.")
(fset 'encoded-kbd-iso2022-esc-dollar-prefix
      encoded-kbd-iso2022-esc-dollar-map)

(defvar encoded-kbd-iso2022-designation-map
  (let ((map (make-sparse-keymap))
	(l charset-list)
	final-char)
    (while l
      (setq final-char (charset-iso-final-char (car l)))
      (if (> final-char 0)
	  (define-key map (char-to-string final-char)
	    'encoded-kbd-iso2022-designation))
      (setq l (cdr l)))
    map)
  "Keymap for handling ISO2022 designation sequence in Encoded-kbd mode.")
(fset 'encoded-kbd-iso2022-designation-prefix
      encoded-kbd-iso2022-designation-map)

;; Keep information of designation state of ISO2022 encoding.  When
;; Encoded-kbd mode is on, this is set to a vector of length 4, the
;; elements are character sets currently designated to graphic
;; registers 0 thru 3.

(defvar encoded-kbd-iso2022-designations nil)
(put 'encoded-kbd-iso2022-designations 'permanent-local t)

;; Keep information of invocation state of ISO2022 encoding.  When
;; Encoded-kbd mode is on, this is set to a vector of length 3,
;; graphic register numbers currently invoked to graphic plane 1 and
;; 2, and a single shifted graphic register number.

(defvar encoded-kbd-iso2022-invocations nil)
(put 'encoded-kbd-iso2022-invocations 'permanent-local t)

(defsubst encoded-kbd-last-key ()
  (let ((keys (this-single-command-keys)))
    (aref keys (1- (length keys)))))

(defun encoded-kbd-iso2022-designation (ignore)
  "Do ISO2022 designation according to the current key in Encoded-kbd mode.
The following key sequence may cause multilingual text insertion."
  (let ((key-seq (this-single-command-keys))
	(prev-g0-charset (aref encoded-kbd-iso2022-designations
			       (aref encoded-kbd-iso2022-invocations 0)))
	intermediate-char final-char
	reg dimension chars charset)
    (if (= (length key-seq) 4)
	;; ESC $ <intermediate-char> <final-char>
	(setq intermediate-char (aref key-seq 2)
	      dimension 2
	      chars (if (< intermediate-char ?,) 94 96)
	      final-char (aref key-seq 3)
	      reg (mod intermediate-char 4))
      (if (= (aref key-seq 1) ?$)
	  ;; ESC $ <final-char>
	  (setq dimension 2
		chars 94
		final-char (aref key-seq 2)
		reg 0)
	;; ESC <intermediate-char> <final-char>
	(setq intermediate-char (aref key-seq 1)
	      dimension 1
	      chars (if (< intermediate-char ?,) 94 96)
	      final-char (aref key-seq 2)
	      reg (mod intermediate-char 4))))
    (aset encoded-kbd-iso2022-designations reg
	  (iso-charset dimension chars final-char)))
  "")

(defun encoded-kbd-iso2022-single-shift (ignore)
  (let ((char (encoded-kbd-last-key)))
    (aset encoded-kbd-iso2022-invocations 2 (if (= char ?\216) 2 3)))
  "")

(defun encoded-kbd-self-insert-iso2022-7bit (ignore)
  (let ((char (encoded-kbd-last-key))
	(charset (aref encoded-kbd-iso2022-designations
		       (or (aref encoded-kbd-iso2022-invocations 2)
			   (aref encoded-kbd-iso2022-invocations 0)))))
    (aset encoded-kbd-iso2022-invocations 2 nil)
    (vector (if (= (charset-dimension charset) 1)
		(make-char charset char)
	      (make-char charset char (read-char-exclusive))))))

(defun encoded-kbd-self-insert-iso2022-8bit (ignore)
  (let ((char (encoded-kbd-last-key))
	(charset (aref encoded-kbd-iso2022-designations
		       (or (aref encoded-kbd-iso2022-invocations 2)
			   (aref encoded-kbd-iso2022-invocations 1)))))
    (aset encoded-kbd-iso2022-invocations 2 nil)
    (vector (if (= (charset-dimension charset) 1)
		(make-char charset char)
	      (make-char charset char (read-char-exclusive))))))

(defun encoded-kbd-self-insert-sjis (ignore)
  (let ((char (encoded-kbd-last-key)))
    (vector
     (if (or (< char ?\xA0) (>= char ?\xE0))
	 (decode-sjis-char (+ (ash char 8) (read-char-exclusive)))
       (make-char 'katakana-jisx0201 char)))))

(defun encoded-kbd-self-insert-big5 (ignore)
  (let ((char (encoded-kbd-last-key)))
    (vector 
     (decode-big5-char (+ (ash char 8) (read-char-exclusive))))))

(defun encoded-kbd-self-insert-ccl (ignore)
  (let ((str (char-to-string (encoded-kbd-last-key)))
	(ccl (coding-system-get (keyboard-coding-system) :ccl-decoder))
	(vec [nil nil nil nil nil nil nil nil nil])
	result)
    (while (= (length (setq result (ccl-execute-on-string ccl vec str t))) 0)
      (dotimes (i 9) (aset vec i nil))
      (setq str (format "%s%c" str (read-char-exclusive))))
    (vector (aref result 0))))


;; Decode list of codes in CODE-LIST by CHARSET and return the decoded
;; characters.  If CODE-LIST is too short for the dimension of
;; CHARSET, read new codes and append them to the tail of CODE-LIST.
;; Return nil if CODE-LIST can't be decoded.

(defun encoded-kbd-decode-code-list (charset code-list)
  (let ((dimension (charset-dimension charset))
	code)
    (while (> dimension (length code-list))
      (nconc code-list (list (read-char-exclusive))))
    (setq code (car code-list))
    (if (= dimension 1)
	(decode-char charset code)
      (setq code-list (cdr code-list)
	    code (logior (lsh code 8) (car code-list)))
      (if (= dimension 2)
	  (decode-char charset code)
	(setq code-list (cdr code-list)
	      code (logior (lsh code 8) (car code-list)))
	(if (= dimension 3)
	    (decode-char charset code)
	  ;; As Emacs can't handle full 32-bit integer, we must give a
	  ;; cons of higher and lower 16-bit codes to decode-char.
	  (setq code (cons (lsh code -8)
			   (logior (lsh (car code-list) 8) (cadr code-list))))
	  (decode-char charset code))))))

(defun encoded-kbd-self-insert-charset (ignore)
  (let ((charset-list
	 (coding-system-get (keyboard-coding-system) :charset-list))
	(code-list (list (encoded-kbd-last-key)))
	tail char)
    (while (and charset-list (not char))
      (setq char (encoded-kbd-decode-code-list (car charset-list) code-list)
	    charset-list (cdr charset-list)))
    (if char
	(vector char)
      (setq unread-command-events (cdr code-list))
      (vector (car code-list)))))

(defun encoded-kbd-self-insert-utf-8 (arg)
  (interactive "p")
  (let ((char (encoded-kbd-last-key))
	len)
    (cond ((< char #xE0)
	   (setq len 1 char (logand char #x1F)))
	  ((< char #xF0)
	   (setq len 2 char (logand char #x0F)))
	  ((< char #xF8)
	   (setq len 3 char (logand char #x07)))
	  (t
	   (setq len 4 char 0)))
    (while (> len 0)
      (setq char (logior (lsh char 6) (logand (read-char-exclusive) #x3F))
	    len (1- len)))
    (vector char)))

(defun encoded-kbd-setup-keymap (coding)
  ;; At first, reset the keymap.
  (define-key encoded-kbd-mode-map "\e" nil)
  ;; Then setup the keymap according to the keyboard coding system.
  (cond
   ((eq (coding-system-type coding) 'shift-jis)
    (let ((i 128))
      (while (< i 256)
	(define-key key-translation-map
	  (vector i) 'encoded-kbd-self-insert-sjis)
	(setq i (1+ i))))
    8)

   ((eq (coding-system-type coding) 'charset)
    (dolist (elt (mapcar
		  #'(lambda (x) 
		      (let ((dim (charset-dimension x))
			    (code-space (get-charset-property x :code-space)))
			(cons (aref code-space (* (1- dim) 2))
			      (aref code-space (1+ (* (1- dim) 2))))))
		  (coding-system-get coding :charset-list)))
      (let ((from (max (car elt) 128))
	    (to (cdr elt)))
	(while (<= from to)
	  (define-key key-translation-map
	    (vector from) 'encoded-kbd-self-insert-charset)
	  (setq from (1+ from)))))
    8)

   ((eq (coding-system-type coding) 'iso-2022)
    (let ((flags (coding-system-get coding :flags))
	  (designation (coding-system-get coding :designation)))
      (if (memq 'locking-shift flags)
	  nil				; Don't support locking-shift.
	(setq encoded-kbd-iso2022-designations (make-vector 4 nil)
	      encoded-kbd-iso2022-invocations (make-vector 3 nil))
	(dotimes (i 4)
	  (if (aref designation i)
	      (if (charsetp (aref designation i))
		  (aset encoded-kbd-iso2022-designations
			i (aref designation i))
		(if (charsetp (car-safe (aref designation i)))
		    (aset encoded-kbd-iso2022-designations
			  i (car (aref designation i)))))))
	(aset encoded-kbd-iso2022-invocations 0 0)
	(if (aref encoded-kbd-iso2022-designations 1)
	    (aset encoded-kbd-iso2022-invocations 1 1))
	(when (memq 'designation flags)
	  (define-key encoded-kbd-mode-map "\e" 'encoded-kbd-iso2022-esc-prefix)
	  (define-key key-translation-map "\e" 'encoded-kbd-iso2022-esc-prefix))
	(when (or (aref designation 2) (aref designation 3))
	  (define-key key-translation-map
	    [?\216] 'encoded-kbd-iso2022-single-shift)
	  (define-key key-translation-map
	    [?\217] 'encoded-kbd-iso2022-single-shift))
	(or (eq (aref designation 0) 'ascii)
	    (dotimes (i 96)
	      (define-key key-translation-map
		(vector (+ 32 i)) 'encoded-kbd-self-insert-iso2022-7bit)))
	(if (memq '7-bit flags)
	    t
	  (dotimes (i 96)
	    (define-key key-translation-map
	      (vector (+ 160 i)) 'encoded-kbd-self-insert-iso2022-8bit))
	  8))))

   ((eq (coding-system-type coding) 4)	; CCL-base
    (let ((valid-codes (or (coding-system-get coding :valid)
			   '((128 . 255))))
	  elt from to valid)
      (while valid-codes
	(setq elt (car valid-codes) valid-codes (cdr valid-codes))
	(if (consp elt)
	    (setq from (car elt) to (cdr elt))
	  (setq from (setq to elt)))
	(while (<= from to)
	  (if (>= from 128)
	      (define-key key-translation-map
		(vector from) 'encoded-kbd-self-insert-ccl))
	  (setq from (1+ from))))
      8))

   ((eq (coding-system-type coding) 'utf-8)
    (let ((i #xC0))
      (while (< i 256)
	(define-key key-translation-map
	  (vector i) 'encoded-kbd-self-insert-utf-8)
	(setq i (1+ i))))
    8)

   (t
    nil)))

;; key-translation-map at the time Encoded-kbd mode is turned on is
;; saved here.
(defvar saved-key-translation-map nil)

;; Input mode at the time Encoded-kbd mode is turned on is saved here.
(defvar saved-input-mode nil)

(put 'encoded-kbd-mode 'permanent-local t)
;;;###autoload
(define-minor-mode encoded-kbd-mode
  "Toggle Encoded-kbd minor mode.
With arg, turn Encoded-kbd mode on if and only if arg is positive.

You should not turn this mode on manually, instead use the command
\\[set-keyboard-coding-system] which turns on or off this mode
automatically.

In Encoded-kbd mode, a text sent from keyboard is accepted
as a multilingual text encoded in a coding system set by
\\[set-keyboard-coding-system]."
  :global t :group 'keyboard :group 'mule

  (if encoded-kbd-mode
      ;; We are turning on Encoded-kbd mode.
      (let ((coding (keyboard-coding-system))
	    result)
	(or saved-key-translation-map
	    (if (keymapp key-translation-map)
		(setq saved-key-translation-map
		      (copy-keymap key-translation-map))
	      (setq key-translation-map (make-sparse-keymap))))
	(or saved-input-mode
	    (setq saved-input-mode
		  (current-input-mode)))
	(setq result (and coding (encoded-kbd-setup-keymap coding)))
	(if result
	    (if (eq result 8)
		(set-input-mode
		 (nth 0 saved-input-mode) 
		 (nth 1 saved-input-mode)
		 'use-8th-bit
		 (nth 3 saved-input-mode)))
	  (setq encoded-kbd-mode nil
		saved-key-translation-map nil
		saved-input-mode nil)
	  (error "Unsupported coding system in Encoded-kbd mode: %S"
		 coding)))

    ;; We are turning off Encoded-kbd mode.
    (when saved-input-mode
      (setq key-translation-map saved-key-translation-map
	    saved-key-translation-map nil)
      (apply 'set-input-mode saved-input-mode)
      (setq saved-input-mode nil))))

(provide 'encoded-kb)

;;; arch-tag: 76f0f9b3-65e7-45c3-b692-59509a87ad44
;;; encoded-kb.el ends here
