# Decisions

- User explicitly selected templates, quick paste, the reported fixes and recent-use promotion. Other suggested additions remain out of scope.
- All includes pins in the same activity-sorted list. This gives the user's latest-paste-first requirement precedence over a separate permanently pinned top section.
- Templates extend the existing encrypted store with optional metadata; ADR0011 records compatibility and precise timestamp companions.
- Custom fields are requested in a separate normal key window, preserving the original paste destination. No background network or permission changes.
- Local packaging uses the existing release script; no release, npm publish, Homebrew update or merge is authorized/performed.
