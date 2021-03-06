;;; helm-ipython.el --- python completion using ipython and helm. -*- lexical-binding: t -*-

;; Copyright (C) 2012 ~ 2018 <Thierry Volpiatto>thierry.volpiatto@gmail.com

;; Author: Thierry Volpiatto

;; Keywords: ipython, python, completion.

;; Package-Requires: ((helm "1.7.8") (emacs "25"))

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

;;; Commentary:
;;
;; 
;; This package is called helm-ipython because initially it needed
;; Ipython and ipython.el as dependency.  Now it is working with default
;; python.el configuration and no other dependencies but it is working
;; also with Ipython, in this case you will have to modify your
;; python.el configuration like this:
;;
;;    (setq python-shell-interpreter "ipython"
;;          python-shell-interpreter-args "-i")


;;; Code:

(require 'cl-lib)
(require 'python)
(require 'helm-elisp) ; For `with-helm-show-completion'

(defgroup helm-ipython nil
  "Helm python completion."
  :group 'helm)

(defcustom helm-ipython-docstring-fm-cmd "help(%s)"
  "Python command to get docstring from interpreter."
  :group 'helm-ipython
  :type 'string)

;;; Internal
(defvar helm-ipython--last-help-candidate nil)
(make-local-variable 'helm-ipython--last-help-candidate)
(defvar helm-ipython-help-buffer "*helm ipython help*")

(defun helm-ipython-completion-list ()
  (condition-case nil
      (with-helm-current-buffer
        (python-shell-completion-get-completions
         (python-shell-get-process)
         nil helm-pattern))
    (error nil)))

(defun helm-ipyton-default-action (elm)
  "Insert completion at point."
  (let ((initial-pattern (helm-ipython-get-initial-pattern)))
    (delete-char (- (length initial-pattern)))
    (insert elm)))

(defvar helm-ipython-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map helm-map)
    (define-key map (kbd "<right>") 'helm-yank-selection)
    (define-key map (kbd "<left>") 'helm-ipython-previous-level)
    map))

(defvar helm-source-ipython
  (helm-build-sync-source "Ipython completion"
    :candidates 'helm-ipython-completion-list
    :action '(("Insert" . helm-ipyton-default-action)
              ("Show info" . helm-ipython-help))
    :persistent-action 'helm-ipython-help
    :persistent-help "Get info on object"
    :keymap helm-ipython-map
    :volatile t
    :requires-pattern 2))

(defun helm-ipython-previous-level ()
  (interactive)
  (helm-set-pattern
   (concat
    (mapconcat 'identity
               (butlast (split-string helm-pattern "\\." t)) ".")
    ".")))

(defun helm-ipython-docstring (candidate)
  (with-helm-current-buffer
    (python-shell-send-string-no-output
     (format helm-ipython-docstring-fm-cmd candidate))))

(defun helm-ipython-help (candidate)
  (if (and (get-buffer-window helm-ipython-help-buffer 'visible)
           helm-ipython--last-help-candidate
           (string= candidate helm-ipython--last-help-candidate))
      (kill-buffer helm-ipython-help-buffer)
      (let ((doc (helm-ipython-docstring candidate))
            (inhibit-read-only t))
        (with-current-buffer (get-buffer-create helm-ipython-help-buffer)
          (erase-buffer)
          (save-excursion (insert doc))
          (setq helm-ipython--last-help-candidate candidate)
          (view-mode 1)
          (pop-to-buffer (current-buffer))))))

(defun helm-ipython-get-initial-pattern ()
  "Get the pattern to complete from."
  (let ((beg (save-excursion
               (skip-chars-backward "a-z0-9A-Z_./" (point-at-bol))
               (point))) 
        (end (point)))
    (buffer-substring-no-properties beg end)))

;;;###autoload
(defun helm-ipython-complete ()
  "Preconfigured helm for ipython completions."
  (interactive)
  (when (or (eq major-mode 'python-mode)
            (eq major-mode 'inferior-python-mode))
    (let ((initial-pattern (helm-ipython-get-initial-pattern))
          (helm-execute-action-at-once-if-one t)
          (helm-quit-if-no-candidate (lambda () (message "[No match]"))))
      (unless (string= initial-pattern "")
        (with-helm-show-completion (- (point) (length initial-pattern)) (point)
          (helm :sources 'helm-source-ipython
                :input initial-pattern
                :buffer "*helm ipython*"))))))

;;;###autoload
(defun helm-ipython-import-modules-from-buffer ()
  "Allow user to execute only the import lines of the current *.py file."
  (interactive)
  (when (or (eq major-mode 'python-mode)
            (eq major-mode 'inferior-python-mode))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^\\s-*\\(import\\|from\\)\\s-+" (point-max) t)
        (python-shell-send-region (point-at-bol) (point-at-eol))
        (sit-for 0.1)))
    (message "All imports from `%s' done" (buffer-name))))
  
(provide 'helm-ipython)

;;; helm-ipython.el ends here
