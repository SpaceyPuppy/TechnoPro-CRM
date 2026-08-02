# Attachment uploads

Ticket attachments accept JPEG, PNG, GIF, WebP, PDF, Word, Excel and plain-text
files. The server enforces the configured `MAX_FILE_SIZE_MB` value (10 MB by
default) and streams each upload to a temporary file before it creates a ticket
attachment record or stores the final attachment file.

The upload API reports these stable error codes:

- `ATTACHMENT_REQUIRED` — no file field was supplied.
- `UNSUPPORTED_ATTACHMENT_TYPE` — the multipart MIME type is outside the
  server allowlist.
- `ATTACHMENT_TOO_LARGE` — the file exceeded the configured per-file limit.
- `ATTACHMENT_UPLOAD_FAILED` — an interrupted or storage failure occurred.

The Android camera/gallery picker continues to submit image files. The native
client checks the default 10 MB limit before upload and turns the API codes into
actionable messages; the server remains authoritative for all type and size
checks.
