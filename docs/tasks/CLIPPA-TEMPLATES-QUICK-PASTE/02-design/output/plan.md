# Native UI and behavior specification

Reuse Clippa's semantic typography, teal accent, 560-point glass panel, SF Symbols and existing row metrics. Keep a single newest-activity list, including pins, to satisfy promotion to first place. Templates get a distinct filter, title/body hierarchy and folder filter. Command-1…9 badges attach to the first nine visible results; a compact footer explains keyboard navigation.

New Template is a discoverable header/menu action. The editor is a separate normal key window: Name and optional Folder fields, labeled multiline Body editor, variable help, Cancel and Save Template footer. Save is disabled for blank title/body; cancellation preserves existing history. Editing a template retains its ID. Use a resizable window with a scrollable form and fixed footer.

Selecting a template without custom variables pastes immediately. With variables, a normal key window requests each unique variable and shows a live text preview. Date/time resolve automatically. Paste is disabled until custom values are nonblank. Cancel never writes the clipboard. Preserve the original destination across this window and record usage on the original template only after submission.

Panel key handling is scoped to its own window. Search caret/selection/word movement and Cmd-C/X/A/Z retain native behavior. Cmd-[ / Cmd-] switch filters; unmodified Up/Down navigate rows; Return pastes. Template controls use native keyboard focus, labeled fields, Escape cancellation and Cmd-S/Return primary actions. New errors are inline/readable and require no permission changes. Reuse reduced-motion behavior for row reordering.

Check empty/content/error, filtered/reordered list, long title/body, Unicode variables, dark/light appearance, keyboard cancellation/editing and focus restoration. VoiceOver/contrast settings that cannot be exercised must remain explicitly unverified.
