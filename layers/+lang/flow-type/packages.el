;;; packages.el --- flow-type layer packages file for Spacemacs.
;;
;; Copyright (c) 2012-2016 Sylvain Benner & Contributors
;;
;; Author: Jonathan del Strother <jdelStrother@gmail.com>
;; URL: https://github.com/syl20bnr/spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

(defconst flow-type-packages
  '(company
    (company-flow :toggle (configuration-layer/package-usedp 'company))
    (flycheck-flow :toggle (configuration-layer/package-usedp 'flycheck))
    eldoc
    js2-mode))

(defun flow-type/post-init-eldoc()
  (when (configuration-layer/package-usedp 'js2-mode)
    (push 'flow-type/enable-eldoc js2-mode-hook))
  (when (configuration-layer/layer-usedp 'react)
    (push 'flow-type/enable-eldoc react-mode-hook)))

(defun flow-type/post-init-company()
  (spacemacs|add-company-backends :backends company-flow :modes js2-mode react-mode))

(defun flow-type/post-init-js2-mode()
  (require 'compile)
  (spacemacs/declare-prefix-for-mode 'js2-mode "mf" "flow" "flow type checker commands")
  (spacemacs/set-leader-keys-for-major-mode 'js2-mode
    "fs" 'flow-type/show-start-server
    "fc" 'flow-type/status
    "fC" 'flow-type/check
    "ft" 'flow-type/show-type-at-cursor)
  (when flow-type/no-auto-start
    (add-to-list 'flycheck-javascript-flow-args "--no-auto-start"))
  (when (eq 'process flow-type/no-auto-start)
    (add-hook 'js2-mode-hook 'flow-type/ensure-server-buffer))
  (add-to-list 'compilation-error-regexp-alist-alist
               '(flow "^\\([^:\n]+\\):\\([0-9]+\\)$" 1 2))
  (add-to-list 'compilation-error-regexp-alist 'flow)
  (add-to-list 'spacemacs-jump-handlers-js2-mode 'flow-type/jump-to-definition))

;; There's no flow-type/post-init-react hook, so we have to do this dance:
(defun flow-type/add-react-jump-handler()
  (add-to-list 'spacemacs-jump-handlers-react-mode 'flow-type/jump-to-definition)
  (remove-hook 'react-mode-hook 'flow-type/add-react-jump-handler))
(add-hook 'react-mode-hook 'flow-type/add-react-jump-handler)

(defun flow-type/init-company-flow ()
  (use-package company-flow
    :defer t
    :config
    (when (configuration-layer/layer-usedp 'react)
      (push 'react-mode company-flow-modes))))

(defun flow-type/init-flycheck-flow()
  (with-eval-after-load 'flycheck
    (use-package flycheck-flow
      :config
      (progn
        ;; Don't run flow if there's no @flow pragma
        (custom-set-variables '(flycheck-javascript-flow-args (quote ("--respect-pragma"))))
        ;; Run flow in react-mode files
        (flycheck-add-mode 'javascript-flow 'react-mode)
        ;; After running js-flow, run js-eslint
        (flycheck-add-next-checker 'javascript-flow 'javascript-eslint)
      ))))
