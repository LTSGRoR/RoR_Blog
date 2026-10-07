# Post editor UX/UI audit — 2026-10-07

Scope: post and revision editor components, reading styles, links, alignment, captions, and image resizing. Reviewed against the app design tokens and [Web Interface Guidelines](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md).

## Findings fixed

- `editor_link_controller.js`: linking multiple paragraphs merged them and could replace formatting. The editor now reads the exact selected text and preserves multi-paragraph/image content while changing its link. The dialog explains why the text field is read-only for these selections.
- `editor_link_controller.js`: asynchronous dialog-close selection restoration could move the cursor during the next action. Cancel and save restore selection immediately; detached controllers do not refocus the editor.
- `editor_link_controller.js`: the link shortcut could bypass the toolbar disabled state for image selections. Keyboard linking now respects Trix formatting availability.
- `editor_link_controller.js`: link interception stopped working after disconnect/reconnect. Cleanup now clears the toolbar reference so listeners are reattached. The link button is keyboard-focusable.
- `editor_alignment_controller.js`: alignment buttons disappeared after disconnect/reconnect. The removed group and toolbar references now reset, restoring exactly one set of buttons.
- `image_size_controller.js`: centered and right-aligned images could not grow because the limit used only the space to their right. Resize limits now use the containing block width.
- `image_size_controller.js`: deleting an attachment during a drag could throw an error. The drag now releases pointer capture and hides the controls safely.

## UI kept consistent

Light code panels and plain monospace text; shared editing/reading styles; centered captions that wrap within image width; compact 30px desktop and 36px touch toolbar controls; neutral selection states; no red image selection border; visible keyboard focus.

## Verification

Chromium checks passed for real ES module startup and typing, all alignments, mixed paragraphs/headings/quotes/code/lists, toolbar reconnection, link insertion/update/removal, unsafe URL rejection, Enter/Escape, preserved multi-paragraph formatting, disabled image-link keyboard behavior, and no accidental post submission. Desktop/mobile styles, long captions, and actual mouse resizing of left/center/right images were checked. JavaScript checks, four Ruby storage/rendering tests with 36 assertions, CSS build, and diff checks passed.

The browser harness uses real Trix and compiled app styles. These are component checks, not an authenticated full-page application test or a claim that every possible editing sequence is covered.
