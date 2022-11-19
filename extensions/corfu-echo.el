;;; corfu-echo.el --- Show candidate documentation in echo area -*- lexical-binding: t -*-

;; Copyright (C) 2021-2022  Free Software Foundation, Inc.

;; Author: Daniel Mendler <mail@daniel-mendler.de>
;; Maintainer: Daniel Mendler <mail@daniel-mendler.de>
;; Created: 2022
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (corfu "0.29"))
;; Homepage: https://github.com/minad/corfu

;; This file is part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Show candidate documentation in echo area. Enable `corfu-echo-mode'.

;;; Code:

(require 'corfu)
(eval-when-compile
  (require 'subr-x))

(defface corfu-echo
  '((t :inherit completions-annotations))
  "Face used for echo area messages."
  :group 'corfu-faces)

(defcustom corfu-echo-delay '(1.0 . 0.5)
  "Show documentation string in the echo area after that number of seconds.
Set to t for an instant message. The value can be a pair of two
floats to specify initial and subsequent delay."
  :type '(choice (const :tag "Never" nil)
                 (const :tag "Instant" t)
                 (number :tag "Delay in seconds")
                 (cons :tag "Two Delays"
                       (choice :tag "Initial   " number)
                       (choice :tag "Subsequent" number)))
  :group 'corfu)

(defvar-local corfu-echo--timer nil
  "Echo area message timer.")

(defvar-local corfu-echo--message nil
  "Last echo message.")

(defun corfu-echo--refresh ()
  "Refresh message to avoid flicker."
  (corfu-echo--cancel corfu-echo--message))

(defun corfu-echo--cancel (&optional msg)
  "Cancel echo timer and refresh MSG."
  (when corfu-echo--timer
    (cancel-timer corfu-echo--timer)
    (setq corfu-echo--timer nil))
  (corfu-echo--show msg)
  (unless corfu--echo-message
    (kill-local-variable 'corfu-echo--timer)
    (kill-local-variable 'corfu-echo--message)))

(defun corfu-echo--show (msg)
  "Show MSG in echo area."
  (when (or msg corfu-echo--message)
    (setq msg (or msg "")
          corfu-echo--message msg)
    (corfu--message "%s" (if (text-property-not-all 0 (length msg) 'face nil msg)
                             msg
                           (propertize msg 'face 'corfu-echo)))))

(defun corfu-echo--exhibit (&rest _)
  "Show documentation string of current candidate in echo area."
  (if-let* ((delay (if (consp corfu-echo-delay)
                       (funcall (if corfu-echo--message #'cdr #'car)
                                corfu-echo-delay)
                     corfu-echo-delay))
            (fun (plist-get corfu--extra :company-docsig))
            (cand (and (>= corfu--index 0)
                       (nth corfu--index corfu--candidates))))
      (if (or (eq delay t) (<= delay 0))
          (corfu-echo--show (funcall fun cand))
        (corfu-echo--cancel)
        (setq corfu-echo--timer
              (run-at-time delay nil
                           (lambda ()
                             (corfu-echo--show (funcall fun cand))))))
    (corfu-echo--cancel)))

;;;###autoload
(define-minor-mode corfu-echo-mode
  "Show candidate documentation in echo area."
  :global t :group 'corfu
  (cond
   (corfu-echo-mode
    (advice-add #'corfu--pre-command :before #'corfu-echo--refresh)
    (advice-add #'corfu--exhibit :after #'corfu-echo--exhibit)
    (advice-add #'corfu--teardown :before #'corfu-echo--cancel))
   (t
    (advice-remove #'corfu--pre-command #'corfu-echo--refresh)
    (advice-remove #'corfu--exhibit #'corfu-echo--exhibit)
    (advice-remove #'corfu--teardown #'corfu-echo--cancel))))

(provide 'corfu-echo)
;;; corfu-echo.el ends here
