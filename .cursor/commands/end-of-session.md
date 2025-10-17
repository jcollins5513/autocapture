## End-of-Session Checklist

### ✅ Done this session
- Background generation is working end-to-end using `gpt-image-1`, with direct base64 decoding and verbose logging for troubleshooting.
- `Docs/granular-plan.md` now reflects completed AI background infrastructure tasks (service creation, API wiring, prompt templating).
- The visual editor syncs captured `ProcessedImage` subjects into the active composition, adds deletion controls, and softens the selection glow.

### 🔜 Still outstanding (see granular-plan.md)
- Phase 4.1: Implement generation queue/caching.
- Phase 4.1: Add prompt validation + better error handling.
- Phase 3 (editor): improve layer tooling (drag/drop ordering UI, property controls, undo/redo) and finish transparency polish for imported layers.

### 🧭 Next-session prep
- Run `swiftlint` before committing any changes.
- Use the updated prompt in `start-of-session.md` to resume work exactly where we left off.
- Prioritise visual-editor polish (Phase 3) while keeping an eye on background-generation stability (Phase 4).

This wraps the current session and captures all context needed for the next one.
