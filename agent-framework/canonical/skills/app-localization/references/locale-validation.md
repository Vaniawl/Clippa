# Locale validation

- Inspect String Catalog source keys, comments, states and extraction settings. Keep existing stable
  keys and translator context; avoid concatenated sentences. Preserve format arguments/types and
  localization for accessibility labels, errors, notifications and purchases where affected.
- Check plural categories for the target language with zero/one/few/many and large counts as
  applicable; test missing translation/fallback behavior. Format dates, numbers, currency and units
  with locale-aware APIs; language, region and time zone are distinct settings.
- Run pseudolocalized/long strings, largest supported text and an RTL locale. Verify natural
  leading/trailing alignment, directional assets and text input; do not mirror nondirectional
  artwork or assume screenshots establish all interactions.
- Record device/OS/build/locale and inspect affected loading/error/empty/permission states. Source
  resource validation is separate from runtime layout and native-language review.
- Align store metadata/creative claims with available app languages. Draft in an assigned locale
  scope; flag terms requiring a qualified reviewer, especially safety, billing or legal language.

Source: [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog).
Applicability: [source registry](../../../references/apple-source-registry.md).
