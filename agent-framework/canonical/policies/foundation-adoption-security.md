# Foundation adoption trust boundary

This framework reference complements each application's own threat model. Installation
does not replace that threat model or assess the application's runtime security.

## Assets and assumptions

Protect existing app code, identity, targets, CI, product documents, provider settings,
native orchestration policy, custom agents and user work. Treat path metadata and ownership
path/mode claims as potentially malformed, and source changes as concurrent. Existing
ownership ledgers must have a reviewed, trusted installation history: matching target ledger
hashes authorize replacing recorded files and are not cryptographically authenticated.
The developer must review and trust the selected local source commit: the
installer executes its Python renderer in isolation, not in a security sandbox. A committed
source is provenance, not proof that its code is safe. A malicious process with equivalent
filesystem privileges is outside the transaction's protection.

## Source → staging → target controls

- `install-apple-team.py` accepts a local Git root; real installation requires a committed
  payload. Explicit legacy baselines must be ancestors of the selected source commit.
  Known source bytes and vendor hashes from those source commits add proof of legacy
  ownership without manually seeding target hashes. Prior trusted installation ledgers also
  authorize recorded files; forged matching ledger hashes can misrepresent customization.
  Review ledger integrity before adoption rather than assuming source-only proof.
- Self-install and framework-source targets are refused. Source development homes require
  separately reviewed canonical/tooling edits; removing their marker is not authorization.
- Planning and rendering occur in a private temporary copy. Paths must stay inside the
  selected root, without symlinks. Unknown/customized collisions fail before target writes.
  Generated full ownership is limited to actual renderer outputs and historical generated
  profile/skill/rule families; a stale full record cannot delete user settings or root
  metadata. Managed instruction blocks retain their outer app-specific text.
- Existing provider settings and native OpenCode policy are preserved. Custom OpenCode
  agents receive collision-free role aliases; explicit team/model preferences stay owned
  by the project. CI workflows, native validators, existing build/test commands, application
  files and product documents are excluded from replacement. Missing scaffolding is additive.
- Source HEAD/payload and destination bytes/modes are rechecked during planning and before
  commit. Same-directory staging and atomic replacement use a rollback journal; a failed
  transaction restores the pre-install destinations. This is not a cross-process lock:
  competing edits after a check remain a residual race, so writers must serialize ownership.
- Dry-run performs the same isolated render and leaves the target unchanged. Render/drift
  success proves configuration consistency, not native app behavior or professional UI.

## Provider and network limits

Installation makes no network/provider calls and changes no global provider settings.
Subsequent provider execution has separate sandbox, approval, MCP, plugin/hook and model
connection boundaries. Reviewed Codex invocation constraints do not establish a fully
offline environment; real offline sessions still require the configured provider-risk
acknowledgment. No role or installed instruction expands a project's external authority.
