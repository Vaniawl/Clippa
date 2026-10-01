# GENERATED — DO NOT EDIT. Run scripts/agent-framework/design-tokens/generate.py.
# LIGHT ONLY by design: terminals own their palette and expose no reliable app-theme signal.
# Consumers must honor NO_COLOR and TERM=dumb before applying these escape sequences.
# Color must never be the only channel for status or meaning.

readonly SKYPHOENIX_ANSI_RESET='\033[0m'
# token=brand.color.accent; source=www/assets/css/custom.css:11 | portal/includes/header.php:112; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_ACCENT_TRUECOLOR='\033[38;2;14;165;233m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_ACCENT_COLOR256='\033[38;5;38m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_ACCENT_COLOR16='\033[34m'
# token=brand.color.logo-ink; source=www/assets/logos/skyphoenix-logo.svg:5-23 | design-system/brand/logo/skyphoenix-logo-color.svg; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_INK_TRUECOLOR='\033[38;2;35;24;21m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_INK_COLOR256='\033[38;5;234m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_INK_COLOR16='\033[30m'
# token=brand.color.logo-orange; source=www/assets/logos/skyphoenix-logo.svg:5-23 | design-system/brand/logo/skyphoenix-logo-color.svg; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_ORANGE_TRUECOLOR='\033[38;2;237;109;31m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_ORANGE_COLOR256='\033[38;5;208m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_ORANGE_COLOR16='\033[33m'
# token=brand.color.logo-red; source=www/assets/logos/skyphoenix-logo.svg:5-23 | design-system/brand/logo/skyphoenix-logo-color.svg; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_RED_TRUECOLOR='\033[38;2;185;45;38m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_RED_COLOR256='\033[38;5;124m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_LOGO_RED_COLOR16='\033[31m'
# token=brand.color.primary; source=www/assets/css/custom.css:8 | www/partials/header.php:66 | portal/includes/header.php:110; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_TRUECOLOR='\033[38;2;30;58;95m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_COLOR256='\033[38;5;24m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_COLOR16='\033[34m'
# token=brand.color.primary-dark; source=www/assets/css/custom.css:9 | www/partials/header.php:67; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_DARK_TRUECOLOR='\033[38;2;21;42;69m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_DARK_COLOR256='\033[38;5;236m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_DARK_COLOR16='\033[34m'
# token=brand.color.primary-light; source=www/partials/header.php:68; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_LIGHT_TRUECOLOR='\033[38;2;45;90;138m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_LIGHT_COLOR256='\033[38;5;24m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_PRIMARY_LIGHT_COLOR16='\033[34m'
# token=brand.color.secondary; source=www/assets/css/custom.css:10 | portal/assets/css/portal.css:5; status=extracted
readonly SKYPHOENIX_BASE_BRAND_COLOR_SECONDARY_TRUECOLOR='\033[38;2;59;130;246m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_SECONDARY_COLOR256='\033[38;5;69m'
readonly SKYPHOENIX_BASE_BRAND_COLOR_SECONDARY_COLOR16='\033[34m'
# token=semantic.color.background; source=www/partials/header.php:113 (bg-white); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_TRUECOLOR='\033[38;2;255;255;255m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_COLOR16='\033[97m'
# token=semantic.color.background-app; source=portal/includes/header.php:122 (bg-gray-50), portal.css:30,39,57,219; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_APP_TRUECOLOR='\033[38;2;249;250;251m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_APP_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_APP_COLOR16='\033[97m'
# token=semantic.color.background-hover; source=www/assets/css/custom.css:83,106; portal.css:54,261; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_HOVER_TRUECOLOR='\033[38;2;239;246;255m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_HOVER_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_HOVER_COLOR16='\033[97m'
# token=semantic.color.background-selected; source=portal/assets/css/portal.css:124,164; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_SELECTED_TRUECOLOR='\033[38;2;219;234;254m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_SELECTED_COLOR256='\033[38;5;189m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_SELECTED_COLOR16='\033[35m'
# token=semantic.color.background-subtle; source=www/assets/css/custom.css:14 (--color-bg-light); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_SUBTLE_TRUECOLOR='\033[38;2;248;250;252m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_SUBTLE_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BACKGROUND_SUBTLE_COLOR16='\033[97m'
# token=semantic.color.border; source=www/assets/css/custom.css:15 (--color-border), portal.css:31; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BORDER_TRUECOLOR='\033[38;2;229;231;235m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BORDER_COLOR256='\033[38;5;254m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BORDER_COLOR16='\033[97m'
# token=semantic.color.border-strong; source=portal/assets/css/portal.css:68,111,216 (inputs, outline buttons); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BORDER_STRONG_TRUECOLOR='\033[38;2;209;213;219m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BORDER_STRONG_COLOR256='\033[38;5;188m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BORDER_STRONG_COLOR16='\033[97m'
# token=semantic.color.brand-surface; source=www/index.php:275 (CTA band bg-primary), portal sidebar active; status=extracted; resolved-from=brand.color.primary
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BRAND_SURFACE_TRUECOLOR='\033[38;2;30;58;95m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BRAND_SURFACE_COLOR256='\033[38;5;237m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_BRAND_SURFACE_COLOR16='\033[34m'
# token=semantic.color.cta-fill; source=design-system/tokens/base.json brand.color.logo-orange | design-system/cross-platform-standard.md section 1; status=approved-derived; resolved-from=brand.color.logo-orange
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_CTA_FILL_TRUECOLOR='\033[38;2;237;109;31m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_CTA_FILL_COLOR256='\033[38;5;208m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_CTA_FILL_COLOR16='\033[33m'
# token=semantic.color.cta-text-on-fill; source=design-system/tokens/base.json brand.color.logo-ink | design-system/cross-platform-standard.md section 1; status=approved-derived; resolved-from=brand.color.logo-ink
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_CTA_TEXT_ON_FILL_TRUECOLOR='\033[38;2;35;24;21m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_CTA_TEXT_ON_FILL_COLOR256='\033[38;5;234m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_CTA_TEXT_ON_FILL_COLOR16='\033[30m'
# token=semantic.color.danger; source=portal/assets/css/portal.css:180,222; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_DANGER_TRUECOLOR='\033[38;2;220;38;38m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_DANGER_COLOR256='\033[38;5;196m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_DANGER_COLOR16='\033[31m'
# token=semantic.color.error-bg; source=portal/assets/css/portal.css:271; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_BG_TRUECOLOR='\033[38;2;254;242;242m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_BG_COLOR256='\033[38;5;255m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_BG_COLOR16='\033[97m'
# token=semantic.color.error-border; source=portal/assets/css/portal.css:272; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_BORDER_TRUECOLOR='\033[38;2;254;202;202m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_BORDER_COLOR256='\033[38;5;224m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_BORDER_COLOR16='\033[31m'
# token=semantic.color.error-text; source=portal/assets/css/portal.css:273; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_TEXT_TRUECOLOR='\033[38;2;153;27;27m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_TEXT_COLOR256='\033[38;5;88m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_ERROR_TEXT_COLOR16='\033[31m'
# token=semantic.color.focus-outline; source=www/assets/css/custom.css:40-47 (2px solid, offset 2px), portal.css:4-7; status=extracted; resolved-from=brand.color.secondary
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOCUS_OUTLINE_TRUECOLOR='\033[38;2;59;130;246m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOCUS_OUTLINE_COLOR256='\033[38;5;69m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOCUS_OUTLINE_COLOR16='\033[34m'
# token=semantic.color.footer-bg; source=www/partials/footer.php:5 (bg-gray-900); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOOTER_BG_TRUECOLOR='\033[38;2;17;24;39m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOOTER_BG_COLOR256='\033[38;5;234m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOOTER_BG_COLOR16='\033[30m'
# token=semantic.color.footer-text; source=www/partials/footer.php:5 (text-gray-300); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOOTER_TEXT_TRUECOLOR='\033[38;2;209;213;219m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOOTER_TEXT_COLOR256='\033[38;5;188m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_FOOTER_TEXT_COLOR16='\033[97m'
# token=semantic.color.info-bg; source=portal/assets/css/portal.css:261; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_BG_TRUECOLOR='\033[38;2;239;246;255m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_BG_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_BG_COLOR16='\033[97m'
# token=semantic.color.info-border; source=portal/assets/css/portal.css:262; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_BORDER_TRUECOLOR='\033[38;2;191;219;254m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_BORDER_COLOR256='\033[38;5;153m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_BORDER_COLOR16='\033[35m'
# token=semantic.color.info-text; source=portal/assets/css/portal.css:263; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_TEXT_TRUECOLOR='\033[38;2;30;64;175m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_TEXT_COLOR256='\033[38;5;25m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_INFO_TEXT_COLOR16='\033[34m'
# token=semantic.color.success-bg; source=portal/assets/css/portal.css:266; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_BG_TRUECOLOR='\033[38;2;240;253;244m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_BG_COLOR256='\033[38;5;255m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_BG_COLOR16='\033[97m'
# token=semantic.color.success-border; source=portal/assets/css/portal.css:267; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_BORDER_TRUECOLOR='\033[38;2;187;247;208m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_BORDER_COLOR256='\033[38;5;158m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_BORDER_COLOR16='\033[36m'
# token=semantic.color.success-text; source=portal/assets/css/portal.css:268; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_TEXT_TRUECOLOR='\033[38;2;22;101;52m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_TEXT_COLOR256='\033[38;5;22m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SUCCESS_TEXT_COLOR16='\033[32m'
# token=semantic.color.surface; source=www/index.php:47 (bg-white cards); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SURFACE_TRUECOLOR='\033[38;2;255;255;255m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SURFACE_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_SURFACE_COLOR16='\033[97m'
# token=semantic.color.text-disabled; source=portal/assets/css/portal.css:60,91; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_DISABLED_TRUECOLOR='\033[38;2;156;163;175m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_DISABLED_COLOR256='\033[38;5;248m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_DISABLED_COLOR16='\033[37m'
# token=semantic.color.text-heading; source=portal/assets/css/portal.css:240; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_HEADING_TRUECOLOR='\033[38;2;17;24;39m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_HEADING_COLOR256='\033[38;5;234m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_HEADING_COLOR16='\033[30m'
# token=semantic.color.text-link; source=www/index.php:57 ('Mehr erfahren' links); status=extracted; resolved-from=brand.color.secondary
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_LINK_TRUECOLOR='\033[38;2;59;130;246m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_LINK_COLOR256='\033[38;5;69m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_LINK_COLOR16='\033[34m'
# token=semantic.color.text-muted; source=www/assets/css/custom.css:13 (--color-text-light), portal.css:29,114,245; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_MUTED_TRUECOLOR='\033[38;2;107;114;128m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_MUTED_COLOR256='\033[38;5;243m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_MUTED_COLOR16='\033[37m'
# token=semantic.color.text-on-brand; source=www/index.php:14 (hero), portal/includes/header.php:143 (active nav); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_ON_BRAND_TRUECOLOR='\033[38;2;255;255;255m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_ON_BRAND_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_ON_BRAND_COLOR16='\033[97m'
# token=semantic.color.text-primary; source=www/assets/css/custom.css:12 (--color-text); status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_PRIMARY_TRUECOLOR='\033[38;2;31;41;55m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_PRIMARY_COLOR256='\033[38;5;235m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_PRIMARY_COLOR16='\033[30m'
# token=semantic.color.text-secondary; source=portal/assets/css/portal.css:120,154,177,215; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_SECONDARY_TRUECOLOR='\033[38;2;55;65;81m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_SECONDARY_COLOR256='\033[38;5;238m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_TEXT_SECONDARY_COLOR16='\033[30m'
# token=semantic.color.warning-bg; source=portal/assets/css/portal.css:256; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_BG_TRUECOLOR='\033[38;2;255;251;235m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_BG_COLOR256='\033[38;5;15m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_BG_COLOR16='\033[97m'
# token=semantic.color.warning-border; source=portal/assets/css/portal.css:257; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_BORDER_TRUECOLOR='\033[38;2;253;230;138m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_BORDER_COLOR256='\033[38;5;222m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_BORDER_COLOR16='\033[33m'
# token=semantic.color.warning-text; source=portal/assets/css/portal.css:258; status=extracted
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_TEXT_TRUECOLOR='\033[38;2;146;64;14m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_TEXT_COLOR256='\033[38;5;130m'
readonly SKYPHOENIX_LIGHT_SEMANTIC_COLOR_WARNING_TEXT_COLOR16='\033[33m'
