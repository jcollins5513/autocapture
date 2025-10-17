## Prompt
Resume AutoCapture development by targeting the remaining Phase 3 “Visual Editor & Compositing System” work in `Docs/granular-plan.md`. In this order:
1. Fix the captured-subject transparency pipeline so `ProcessedImage` layers import without white halos and respect alpha inside the editor.
2. Expand the layer management UI (opacity/visibility controls, drag-reorder polish, undo/redo stubs) to align with the open checkboxes in Phase 3.2/3.1.
3. Clean up the background generation diagnostics—replace temporary prints with structured logging and design the caching/queue strategy noted in Phase 4.1.

Run `swiftlint` before committing, keep Docs in sync (granular-plan.md + end-of-session.md), and leave the workspace ready for the next hand-off.

TLDR/ Continue development on autocapture project.
