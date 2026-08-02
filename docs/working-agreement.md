# TechnoPro CRM working agreement

This document defines how Christopher and Codex plan, implement, review, merge, and release TechnoPro CRM work.

## Sources of truth

- The [TechnoPro Development Project](https://github.com/users/SpaceyPuppy/projects/2) is the living roadmap.
- GitHub Issues contain implementation-ready scope and acceptance criteria.
- Pull requests contain proposed repository changes and their review history.
- GitHub Releases contain deliberately bundled test releases.
- `todo.md` is a historical roadmap snapshot, not the active queue.

Planning changes belong in the GitHub Project. They do not require repository commits or documentation-only pull requests.

## Work states

1. **Backlog** — recorded but not scheduled.
2. **Ready** — sufficiently defined to implement.
3. **In progress** — actively being implemented.
4. **Testing** — implementation is in a draft pull request and awaits review or acceptance testing.
5. **Done** — merged and verified to the level required by the Issue.

Future ideas remain draft Project items. Convert a draft item into a repository Issue only when it is ready to enter the implementation queue.

## Codex responsibilities

For an implementation Issue, Codex will:

1. Confirm the Issue and acceptance criteria are sufficiently clear.
2. Move the Project item to **In progress**.
3. Create a focused `agent/<description>` branch.
4. Implement only the Issue's intended scope.
5. Run validation proportionate to the affected behaviour and risk.
6. Record unrelated discoveries as separate Issues or draft items instead of silently expanding scope.
7. Push the branch and open a draft pull request containing:
   - what changed and why;
   - the linked Issue using `Closes #<issue>`;
   - checks performed and their results;
   - manual acceptance testing required;
   - known limitations or risks.
8. Move the Project item to **Testing**.
9. Address review comments and CI failures within the same pull request when they remain in scope.
10. Avoid creating a release or pushing a release tag without Christopher's explicit approval.

## Christopher's responsibilities

For each pull request, Christopher will:

1. Read the summary and linked Issue acceptance criteria.
2. Review the diff to the desired level.
3. Perform manual acceptance testing when the change affects user experience, deployment, permissions, financial behaviour, data integrity, or hardware/device behaviour.
4. Leave review comments or requested changes when needed.
5. Approve and merge when satisfied.
6. Decide when enough merged work exists for a bundled prerelease.

Codex will not merge a pull request unless Christopher explicitly requests it. Merging a pull request containing `Closes #<issue>` closes that Issue. The Project should then move the item to **Done**, automatically where configured.

## Pull-request rules

- Use one focused pull request per implementation Issue.
- Open pull requests as drafts unless they are immediately ready for final review.
- Do not mix roadmap maintenance, unrelated refactoring, opportunistic fixes, or release creation into a feature pull request.
- Keep database migrations forward-safe and preserve existing TechnoPro data.
- Financial, permission, stock, deployment, signing, backup, and migration changes require explicit risk notes.
- A merged pull request does not automatically justify a release.

## Validation and GitHub Actions

- Run automatic checks only for areas affected by a pull request.
- Documentation and Project-only changes should not build the backend, Docker images, or Android application.
- Keep manual full validation available for cross-cutting or high-risk changes.
- Superseded runs should be cancelled when a newer commit is pushed to the same pull request.
- Release validation remains mandatory when a release tag is created.
- A tagged release builds the signed Android APK, container images, VPS bundle, installer and checksums.
- Android and VPS field validation belongs in the release-validation Issue rather than every small pull request.

## Release process

1. Merge focused Issues without releasing every minor change.
2. Christopher decides when a useful bundle is ready.
3. Confirm the intended version and release notes.
4. Push a `v*` tag only after Christopher approves publication.
5. Let the release workflow build and publish the signed APK, GHCR images and VPS installer package.
6. Install the prerelease on the VPS and Android device.
7. Complete the release-validation Issue.
8. Record failures as separate Issues; keep the release marked as a prerelease until it is proven.

## Starting and continuing Codex work

New Codex tasks do not inherit the full history of previous chats. The Issue, this agreement, and `AGENTS.md` provide the durable context.

### Starting from an Issue

The documented GitHub integration currently guarantees Codex mentions in pull-request comments, not implementation delegation from GitHub Issue comments. To begin an Issue reliably:

1. Start a new Codex task for that Issue rather than continuing one permanent conversation.
2. Provide the Issue URL and say: `Implement this Issue in TechnoPro CRM and open a draft pull request.`
3. Continue the work from the resulting pull request.

### Working from a pull request

After [Codex cloud and code review are enabled for the repository](https://learn.chatgpt.com/docs/third-party/github), use pull-request comments such as:

```text
@codex review
```

```text
@codex review focusing on financial and data-integrity regressions
```

```text
@codex fix the P1 issue
```

```text
@codex fix the CI failures
```

`@codex review` requests a GitHub code review. Other `@codex` instructions in a pull-request comment start a Codex cloud task using that pull request as context. Review and merge the resulting changes normally.

## Current implementation order

1. VPS backups and proven restoration.
2. Android MVP stabilisation Issues.
3. Bundled Android and Docker prerelease validation.
4. Native procurement.
5. Inventory ledger and advanced stock control.
6. Point of sale.
7. Deferred integrations and expansion work.
