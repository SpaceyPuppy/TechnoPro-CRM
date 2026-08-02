# GitHub Actions

TechnoPro uses focused workflows so routine documentation and project-management
changes do not rebuild the server or Android application.

## Pull request checks

- **Backend CI** runs when a ready-for-review pull request changes the backend,
  shared package, Docker deployment files, or Node dependency manifests.
- **Android CI** runs when a ready-for-review pull request changes the Flutter
  application or shared API types.
- Draft pull requests do not run the expensive jobs. Mark a draft as ready for
  review when it is ready for automated validation.
- Superseded runs are cancelled when another commit is pushed to the same pull
  request.
- Merging to `main` does not repeat the checks already completed on the pull
  request.

Both CI workflows can be run on demand from **Actions**, by selecting the
workflow and choosing **Run workflow**.

For a documentation-only or metadata-only commit, `[skip ci]` may be included in
the commit message as an additional escape hatch. Do not use it for application,
deployment, dependency, or workflow changes. If required status checks are added
to branch protection later, skipped workflows may need corresponding rules.

## Release and recovery workflows

- **Publish Release** remains tag-driven. A `v*` tag performs release validation,
  builds and signs the APK, publishes server images, and creates the release
  bundle.
- **Export Signing Recovery** remains manual and should only be run when a fresh
  encrypted recovery copy is required.
