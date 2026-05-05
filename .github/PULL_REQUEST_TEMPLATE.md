<!--
Thanks for contributing to He Was Socrates. Please complete the sections
below; checklist items help reviewers verify the PR meets project gates.
-->

## Summary

<!-- 1-3 sentences. What changed and why. Link the issue if applicable. -->

Closes #

## Type of change

- [ ] Bug fix (non-breaking)
- [ ] New feature (non-breaking)
- [ ] Breaking change (requires SpecDD review)
- [ ] Documentation only
- [ ] Build / CI / tooling
- [ ] Refactor (no behavior change)
- [ ] Asset pipeline / viseme regeneration

## Test plan

<!-- Bulleted checklist of how a reviewer can verify this PR locally. -->

- [ ] `make engine-test` — 41 swift-testing scenarios still pass
- [ ] `make assets-verify` — manifest is byte-identical
- [ ] `make ci-local` — local CI parity passes
- [ ] Manual reproduction steps:
      1.
      2.

## Screenshots / recordings

<!-- For UI changes, attach a before/after screenshot or a short screen recording. -->

## Spec impact

- [ ] No impact on `runs/2026-05-05-spec/spec/lock.sha256` (frozen artifacts unchanged)
- [ ] Touches frozen artifacts — SpecDD amendment cycle filed at: <link>
- [ ] Adds a new spec artifact (must be added to lock or explicitly excluded)

## Checklist

- [ ] Conventional Commits used in commit messages (`feat:`, `fix:`, `chore:`, …)
- [ ] Tests added or updated for behavioral changes
- [ ] `swift-format lint -r packages apps tools` passes locally
- [ ] No secrets committed (`make secret-scan` clean)
- [ ] If AI-assisted, the commit message includes a `Co-Authored-By:` trailer
- [ ] Documentation updated (`README.md`, `SETUP.md`, or `docs/`) where relevant
