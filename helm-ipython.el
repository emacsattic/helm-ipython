;;; helm-ipython.el --- python completion using ipython and helm. 

;; Copyright (C) <Thierry Volpiatto>thierry.volpiatto@gmail.com

;; Author: Thierry Volpiatto

;; Keywords: ipython, python, completion. 

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;; 

;; Commentary:
;;
;; Works only in Emacs-24.2
;; Need Ipython and rlcompleter2
;; See Ipython installation in python.el source file
;; or documentation.

;;; Code:

(require 'cl-lib)
(require 'python)
(require 'helm-elisp) ; For `with-helm-show-completion'

(defvar helm-ipython-help-buffer "*helm ipython help*")

(defun helm-ipython-completion-list (pattern)
  (condition-case nil
      (with-helm-current-buffer
        (python-shell-completion-get-completions
         (python-shell-get-process)
         python-shell-completion-string-code
         helm-pattern))
    (error nil)))

(defun helm-ipyton-default-action (elm)
  "Insert completion at point."
  (let ((initial-pattern (helm-ipython-get-initial-pattern)))
    (delete-char (- (length initial-pattern)))
    (insert elm)))

(defvar helm-source-ipython
  '((name . "Ipython completion")
    (candidates . (lambda ()
                    (helm-ipython-completion-list helm-pattern)))
    (action . helm-ipyton-default-action)
    (persistent-action . helm-ipython-help)
    (persistent-help . "Get info on object")
    (volatile)
    (requires-pattern . 2)))

(defun helm-ipython-docstring (candidate)
  (with-helm-current-buffer
    (python-shell-send-string-no-output
     (format "help(\"%s\")" candidate))))

(defun helm-ipython-help (candidate)
  (if (and (get-buffer-window helm-ipython-help-buffer 'visible)
           (string= candidate help-cand))
      (kill-buffer helm-ipython-help-buffer)
      (let ((doc (helm-ipython-docstring candidate)))
        (with-current-buffer (get-buffer-create helm-ipython-help-buffer)
          (erase-buffer)
          (save-excursion (insert doc))
          (setq help-cand candidate)
          (display-buffer (current-buffer))))))

(defun helm-ipython-get-initial-pattern ()
  "Get the pattern to complete from."
  (let ((beg (save-excursion
               (skip-chars-backward "a-z0-9A-Z_./" (point-at-bol))
               (point))) 
        (end (point)))
    (buffer-substring-no-properties beg end)))

(defun helm-ipython-complete ()
  "Preconfigured helm for ipython completions."
  (interactive)
  (delete-other-windows)
  (let ((initial-pattern (helm-ipython-get-initial-pattern))
        (helm-execute-action-at-once-if-one t)
        help-cand
        (helm-quit-if-no-candidate (lambda () (message "[No match]"))))
    (with-helm-show-completion (- (point) (length initial-pattern)) (point)
      (helm :sources 'helm-source-ipython
            :input initial-pattern
            :buffer "*helm ipython*"))))

(defun helm-ipython-import-modules-from-buffer ()
  "Allow user to execute only the import lines of the current *.py file."
  (interactive)
  (with-current-buffer (current-buffer)
    (save-excursion
      (goto-char (point-min))
      (catch 'break
        (while (not (eobp))
          (catch 'continue
            (if (re-search-forward "^\\s-*\\(import\\|from\\)\\s-+" (point-max) t)
                (progn
                  (sit-for 0.1)
                  (python-shell-send-region (point-at-bol) (point-at-eol))
                  (throw 'continue nil))
                (throw 'break nil)))))))
  (message "All imports from `%s' done" (buffer-name)))
  
(provide 'helm-ipython)

;;; helm-ipython.el ends here
