# Mechanical switch sounds

Source: [tplai/kbsim](https://github.com/tplai/kbsim), by Thomas Lai.
Upstream revision: `ba103f3b0afa9dab80447aa2e7e2ed80b6bd80e4`.
Repository license: MIT; the complete notice is in `LICENSE-kbsim.txt` and is bundled with the app.

Each `kbsim-<profile>.wav` is converted from
`src/assets/audio/<profile>/press/GENERIC_R0.mp3` at the revision above.
Original downloads were verified against the Git blob hashes in the upstream tree.
Conversion used `ffmpeg -i input.mp3 -c:a pcm_s16le output.wav`, preserving the source sample rate and channel count.
No gain changes, trimming, synthesis, or mixing were applied.

Tastko uses one generic press sample per switch profile for button feedback.
Upstream also has key-specific variations and release samples; those are not included.

These are recordings of particular keyboard builds. Cases, keycaps, and recording setup
also affect the sound; the profile names identify the source switch recordings.
