# Flicker reduction comparison

Both experimental branches start at main (`e5cff5b`). Run each in a **fresh Julia
process** after switching branches; already loaded Julia modules do not reload.

```sh
git switch fix/buffered-overwrite
julia --project -e 'using TerminalSystemMonitor; monitor()'
# Ctrl-C to exit before switching
git switch fix/line-diff
julia --project -e 'using TerminalSystemMonitor; monitor()'
```

- `fix/buffered-overwrite`: build the entire update in an IOBuffer, overwrite all
  visible lines, then erase unused suffixes and old rows below the frame. One
  output write per sample; no blank screen is sent before drawing.
- `fix/line-diff`: retain cropped, ANSI-styled viewport lines; overwrite only
  changed lines and erase removed rows. Identical frames produce no writes.
  Terminal size changes force a complete refresh, including unused screen space.

The API and sampling interval are unchanged. Compare while resizing the terminal
and while switching between compact and expanded layouts. Both preserve Unicode
cropping, alternate-screen behavior and cursor restoration on exit.

Buffering reduces intermediate output and removing the initial erase avoids a
blank frame, but a terminal can still present a large update incrementally.
Actual perceived flicker depends on the terminal; interactive visual comparison
is still needed. Neither branch requires synchronized-output terminal support.
