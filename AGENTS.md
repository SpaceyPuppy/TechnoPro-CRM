# TechnoPro CRM agent guidance

Read and follow [`docs/working-agreement.md`](docs/working-agreement.md) before planning, implementing, reviewing, or publishing repository work.

## Repository rules

- Treat the TechnoPro Development GitHub Project as the roadmap and GitHub Issues as the scope for implementation-ready work.
- Use one focused `agent/<description>` branch and one draft pull request per Issue.
- Include `Closes #<issue>` in implementation pull requests.
- Do not expand an Issue silently. Record unrelated findings separately.
- Flutter for Android and Windows is the supported product UI. The React application is reference material unless an Issue explicitly says otherwise.
- Do not create a release or push a release tag without Christopher's explicit approval.
- Prefer focused validation for the changed area. State any checks not run and why.
- Preserve existing user data, financial correctness, idempotency, role enforcement, attachment safety, and stock history.

## Code review rules

- Flag financial calculations that use unsafe floating-point arithmetic, can double-apply a payment or billed timer, or bypass finalised-invoice correction rules.
- Flag stock mutations that bypass the transactional stock service or lose their source, actor, reason, timestamp, or cost context.
- Flag API routes that rely on Flutter action hiding instead of server-side role enforcement.
- Flag release or deployment changes that risk existing VPS data, secrets, backup recovery, signed Android updates, or installer re-runs.
