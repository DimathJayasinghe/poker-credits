# Sound effects

Every sound in this folder is original work, made from nothing by `tool/sounds/make_sounds.py`:
no samples, no recordings and nothing downloaded. They carry no third-party licence and need no
credit. They are released under the same MIT licence as the app, and may also be used as CC0 (no
rights reserved).

To change a sound, edit the script and run it again; the output is deterministic (fixed seeds),
so a change to a sound shows up as a reviewable change to the script.

```
python3 tool/sounds/make_sounds.py   # writes assets/sounds/*.wav and tool/sounds/audition.html
python3 tool/sounds/analyze.py       # checks levels, brightness, clicks and length of every file
```

The set follows one palette so that any two sounds heard together belong together:

- Notes are a soft felt mallet on a tine, tuned to D major pentatonic (D E F# A B).
- Chips are small clay discs: a short ring and a low knock. A call is a few chips, a raise more, an
  all-in a long cascade.
- Cards are filtered paper noise (a slide, a flick, a snap). A check is two knuckle taps on felt.
- Everything goes through one small, damped room. Nothing is brighter than about 6 kHz, nothing
  starts with a click, and the peaks stay below -3 dBFS.

Format: 16-bit mono WAV at 22.05 kHz (nothing is above 6.2 kHz, so nothing is lost), about 0.9 MB
in all. WAV needs no decoder on any platform.
