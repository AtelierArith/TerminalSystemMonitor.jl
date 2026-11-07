# Flicker reduction

The user requested two independent branches from main: buffered overwrite and
line differences. Preserve monitor's API, alternate screen, cursor cleanup,
viewport sanitization, Unicode cropping and compact layout.

Both approaches construct the complete update in memory and write it once.
Overwrite refreshes every visible row before erasing its unused suffix and
clears below the new frame only after writing it. Differences retain the previous
cropped, styled rows and refresh changed rows only; resizing invalidates this
cache and removed rows are erased. No new terminal capabilities or dependencies.

Tradeoff: overwrite is simple and stateless; differences reduce terminal traffic
but require previous-frame state. Neither guarantees atomic presentation by the
terminal. Synchronized-output escape modes are outside this comparison.
