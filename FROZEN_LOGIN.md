Login screen UI - Freeze policy
================================

Files considered frozen:
- mobile/lib/features/auth/sign_in_screen.dart
- mobile/lib/features/auth/login_screen.dart

Policy:
- UI design changes to the login/sign-in screens are blocked until approved.
- Small non-UI fixes (comments, logging) are permitted only after review.
- Any change to these files must be approved by the product/design owner.

Local enforcement:
- A git pre-commit hook is provided in `.githooks/pre-commit`.
- To enable the hook locally run:
  __git config core.hooksPath .githooks__

Bypass (only for emergencies):
- You can bypass the hook locally by setting an env var:
  __SKIP_LOGIN_CHECK=1 git commit -m "Emergency: allow login change"__
- Or by using `--no-verify` with `git commit` (less recommended).

CI / GitHub:
- For stricter enforcement, add a CI check that rejects any PR touching the frozen files,
  or add a CODEOWNERS entry so PRs must be reviewed by the owner before merge.

If you want, I can:
- Install the pre-commit hook into the repo for you (I added `.githooks/pre-commit` — you must run the git config command once).
- Add a simple CI job that fails if these files are changed.
- Add a CODEOWNERS file and recommend reviewers.