# Migration and sync decisions

- Identify SwiftData/Core Data model versions and CloudKit development/production environments.
  Inspect actual schema and stores; SDK availability is separate from deployment-target support.
- SwiftData: describe versioned schemas and migration stages when needed; check real relationships,
  uniqueness, defaults and transformations. Core Data: establish lightweight versus custom migration,
  persistent-store options and context/actor ownership. Do not pass managed objects across isolation
  boundaries without the framework-supported identity/context pattern.
- Test fresh store, every supported upgrade, failed/interrupted migration, disk/storage failure and
  reopen. Check invariants and meaningful records, not only whether the store opens. Preserve backups
  only where the storage technology supports safe consistent copying and restore.
- CloudKit production schema changes are additive: existing record types/fields cannot simply be
  deleted. Specify compatibility for released clients; development reset is not production rollback.
  Plan forward-fix or supported backup/restore, and document irreversible data transformations.
- For sync, state stable IDs, duplicate/retry handling, conflict policy, deletes/tombstones, offline
  queueing, account changes/sign-out and permissions/quota failure. Keep local state usable when
  service access fails. Check private/shared/public scope and sensitive data exposure.
- Verify recovery in an isolated environment. Separate a tested restore from a written, unexercised
  procedure; unavailable verification remains NOT RUN. Escalate shared/production destructive work.

Sources: [SwiftData migrations](https://developer.apple.com/documentation/swiftdata/schemamigrationplan),
[Core Data](https://developer.apple.com/documentation/coredata),
[CloudKit deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).
Current applicability and owners: [source registry](../../../references/apple-source-registry.md).
