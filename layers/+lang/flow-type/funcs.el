(defun flow-type/--no-auto-start-arg ()
  (if flow-type/no-auto-start "--no-auto-start" ""))

(defun flow-type/call-process-on-buffer-to-string (command)
  (with-output-to-string
    (call-process-region (point-min) (point-max) shell-file-name nil standard-output nil shell-command-switch command)))

(defun flow-type/get-info-from-def (info)
  (let ((type (alist-get 'type info)))
    (if (not (string-equal type "(unknown)"))
        type)))

(defun flow-type/get-reasons-from-def (info)
  (let ((reasons (alist-get 'reasons info)))
    (if (> (length reasons) 0)
        (alist-get 'desc (aref reasons 0)))))


(defun flow-type/colorize-type (text)
  ;; if web-mode is installed, use that to syntax highlight the type information
  (if (configuration-layer/package-usedp 'web-mode)
      (with-temp-buffer
        (web-mode)
        (insert text)
        (web-mode-set-content-type "jsx")
        (buffer-string))
    ;; otherwise, just return the plain text
    text))

(defun flow-type/describe-info-object (obj)
  (let ((err (alist-get 'error obj)))
    (if err (error err)))
  (let ((info (flow-type/get-info-from-def obj)))
    (if info
        (flow-type/colorize-type info)
      ;; even if the 'info' field is unknown, there's sometimes useful information in the 'reasons' structure.
      (flow-type/get-reasons-from-def obj))))

(defun flow-type/flow-binary ()
    (or
     ;; Try to find flow in node_modules (via 'npm install flow-bin')
      (let ((root (locate-dominating-file buffer-file-name "node_modules")))
        (if root
            (let ((flow-binary (concat root "node_modules/.bin/flow")))
              (if (file-executable-p flow-binary) flow-binary))))
      ;; Fall back to a globally installed binary
      (executable-find "flow")
      ;; give up
      (error "Couldn't find a flow executable")))



(defun flow-type/type-at-cursor ()
  (let ((output (flow-type/call-process-on-buffer-to-string
                 (format "%s type-at-pos %s --retry-if-init=false %s --json %d %d"
                         (flow-type/flow-binary)
                         (if buffer-file-name (concat "--path " buffer-file-name) "")
                         (flow-type/--no-auto-start-arg)
                         (line-number-at-pos) (+ (current-column) 1)))))
    (unless (string-match "\w*flow is still initializing" output)
      (flow-type/describe-info-object (json-read-from-string output)))))

(defun flow-type/show-type-at-cursor ()
  (interactive)
  (message "%s" (flow-type/type-at-cursor)))

(defun flow-type/enable-eldoc ()
  (if (and buffer-file-name (locate-dominating-file buffer-file-name ".flowconfig"))
      (set (make-local-variable 'eldoc-documentation-function) 'flow-type/type-at-cursor)))

(defun flow-type/jump-to-definition ()
  (interactive)
  (let ((output (flow-type/call-process-on-buffer-to-string
                 (format "%s get-def --quiet %s --json --path %s %d %d"
                         (flow-type/flow-binary)
                         (flow-type/--no-auto-start-arg)
                         (buffer-file-name)
                         (line-number-at-pos) (+ (current-column) 1)))))
    (let* ((result (json-read-from-string output))
           (path (alist-get 'path result)))
      (if (> (length path) 0)
          (progn
            (find-file path)
            (goto-char (point-min))
            (forward-line (1- (alist-get 'line result)))
            (forward-char (1- (alist-get 'start result))))))))

(defun flow-type/project-root ()
  (let ((dir (and buffer-file-name
                  (locate-dominating-file buffer-file-name ".flowconfig"))))
    (unless dir
      (error "No .flowconfig found"))
    dir))

(defun flow-type/start-server ()
  (ansi-color-for-comint-mode-on)
  (let ((default-directory (flow-type/project-root)))
    (make-comint (concat "flow " default-directory) (flow-type/flow-binary) nil "server")))

(defun flow-type/show-start-server ()
  (interactive)
  (ansi-color-for-comint-mode-on)
  (let ((buf (flow-type/start-server)))
    (pop-to-buffer buf)))

(defun flow-type/ensure-server-buffer ()
  (let ((default-directory (ignore-errors (flow-type/project-root))))
    (when default-directory (flow-type/start-server))))

(defun flow-type/compile (name command)
  (interactive)
  (let* ((default-directory (flow-type/project-root))
         (bname (concat "*" name " " default-directory "*"))
         (buf (get-buffer bname)))
    (when buf
      (kill-buffer buf))
    (with-current-buffer (compile (format "%s %s" (flow-type/flow-binary) command))
      (rename-buffer bname))))

(defun flow-type/status ()
  (interactive)
  (flow-type/compile
   "flow status"
   (format "status --quiet %s --show-all-errors"
           (flow-type/--no-auto-start-arg))))

(defun flow-type/check ()
  (interactive)
  (flow-type/compile
   "flow check"
   "check --quiet --show-all-errors"))
