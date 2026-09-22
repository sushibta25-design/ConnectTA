# ConnectTA 0.4.0 cleanup audit

The default branch still pointed at ba239153 (A/B-era source), while app selection and later bridge work lived on feature-appbridge-90. This release consolidates the 91 configuration bridge baseline (b251bac8), deliberately excluding failed adaptive experiment 92 (769d8ac).

Removed from the active main source: old runtime method/ivar discovery, scene activation probes, trial selector kicks, overlay host attempts and forced-foreground test loops from the A/B baseline. The later direct native launch path supersedes them.

Removed from baseline 91: duplicate anonymous client80 Darwin status transport and its ten host observers; resize-stage notifications and verbose geometry logs on each resize; duplicate NSLog output. Per-app lifecycle status, bounded file logs and error reports remain. The startup donor retry is retained and bounded, not a perpetual timer.

Preserved: admission capability hooks, scene-role/delegate bridge, root transfer/restoration, Home icon providers, native host alignment, YouTube identity/layout behavior and app-selection transport. Multiple hooks covering distinct system entry points were not deleted merely because their names look similar. No speculative scene/split changes are included.

Renamed: dylib/filter, preference bundle/controller, source prefixes, package identity, preference domain, IPC names, log filenames, workflow/artifact and documentation. Only the legacy preference read and Debian Conflicts/Replaces/Provides retain the old package ID for upgrades.

Historical test branches remain as recovery history and are not built by the main workflow. No unrelated repository or other product was changed.

Validation: package plist/config checks and CI compilation. No measured CPU/temperature improvement or device compatibility claim. Device checks must include replacing the old package (one dylib only), retained ON/OFF settings, CarPlay reconnect, YouTube touch/fullscreen and MultiTA split layout.
