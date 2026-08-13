# Jellyfin CRT Marquee

*[Leer esto en español](README.md)*

### See your shows the way they actually looked.

Remember planting yourself in front of the tube TV on a Saturday morning? The
scanlines, the phosphorescent glow of the RGB mask, that slight screen curvature
that made everything look a little rounded at the edges. That's how classic shows
*really* looked — not on the flat, perfect 4K of a modern monitor, but through a
cathode ray tube, imperfections and all the charm that came with them.

**Jellyfin CRT Marquee** brings that experience back to your Jellyfin library.
One installer, one double-click, and your content plays back inside a full-body
80s CRT television — frame, plastic, buttons and all — with a real tube-emulation
shader applied on top of the image. This isn't an Instagram filter slapped on
afterward: it's the same kind of scanline and phosphor-mask math used by RetroArch
emulators, running live on top of your Jellyfin player.

Put on an 80s show, turn off the lights, and feel like you're watching it for the
first time again.

![Screenshot: SMPTE color bars inside the TV frame with the CRT Lottes shader applied](docs/images/screenshot.png)

*(SMPTE color bars with the `crt-lottes` shader, generated with `mpv --vo=gpu` — see [Testing](#testing))*

## Why you'll like it

- **The TV frame is real**: your video is inserted inside the screen cutout of an
  80s CRT television, complete with frame, buttons and casing — not a simple
  overlay slapped on top.
- **The CRT effect is real, not cosmetic**: screen curvature, scanlines and RGB
  phosphor mask computed live by a GLSL shader, just like retro emulators do — not
  a semi-transparent PNG overlay.
- **Pick your flavor of nostalgia**: three different shaders (Lottes, Aperture,
  Hyllian), each with its own personality, or turn it all off whenever you want to
  go back to modern.
- **One double-click and you're done**: no manual configuration, no editing
  `mpv.conf` yourself — the launcher installs, configures and opens Jellyfin for
  you.

## Usage

1. Double-click `Jellyfin CRT Launcher.bat` (no need to close JMP first, the script does it for you).
2. The script:
   - Closes Jellyfin Media Player if it was open.
   - Copies the shaders and the frame image to JMP's config folder (`%LOCALAPPDATA%\jellyfinmediaplayer`).
   - Enables `useOpenGL` in `jellyfinmediaplayer.conf` (required, otherwise the video shows a black screen — JMP defaults to ANGLE, which doesn't handle multi-pass shaders well).
   - Lets you pick: **CRT Lottes**, **CRT Aperture**, **CRT Hyllian**, just the TV frame with no shader, or disable everything (normal Jellyfin, no frame, no shader) — with the keyboard arrows, by typing the number, or with a **gamepad's D-pad and A button** (XInput/Xbox-style) if one is connected.
   - Opens Jellyfin Media Player automatically with the configuration applied.

To switch shaders later, repeat step 1 (running the launcher again is safe, it doesn't duplicate anything, and it handles closing/reopening JMP for you).

It's portable: you can copy the whole folder to another PC with Jellyfin Media Player installed, it doesn't depend on any particular Windows user.

## How it works (technical summary)

- `mpv.conf` uses `--lavfi-complex` to composite the video inside the screen cutout of the frame PNG (`external-file` instead of the `movie=` filter, because `movie=` doesn't handle Windows drive-letter paths well — a known ffmpeg/mpv bug).
- The screen cutout in the PNG was detected by analyzing the alpha channel with a flood-fill script: `X=109 Y=115 W=822 H=615` on a `1275x832` image.
- The compositing order is black → video → frame **on top**. Because the PNG's cutout is genuinely transparent, the video shows through it and the tube's rounded corners clip the picture. The video is drawn a few pixels larger than the cutout so no seam is visible.
- Each GLSL shader was modified to confine the CRT effect (curvature, scanlines, mask) to that rectangle only — outside of it, the pixel passes through unprocessed, so the effect isn't applied to the TV's plastic casing.
- Jellyfin Media Player **does not** allow switching shaders on the fly with keyboard shortcuts: its UI layer (`inputmaps/*.json`) intercepts every key before it reaches mpv. That's why switching shaders means reinstalling/reconfiguring, not pressing a key inside the app.

## Testing

`test/test-shaders.ps1` validates that all 3 shaders compile and render correctly
using standalone mpv (`winget install --id shinchiro.mpv -e`), without opening
Jellyfin Media Player or clicking anything — it automates the exact diagnostic
process used to fix the `crt-aperture`/`crt-hyllian` bugs. See [docs/TESTING.md](docs/TESTING.md)
for the full story (including a real false positive that happened early on).

```powershell
.\test\test-shaders.ps1
```

## How this project was made

This repository was generated in a conversational programming session with
**Claude** (Anthropic), using **Claude Code** (the official CLI agent) as the tool.

- **AI assistant**: Claude, by Anthropic. The session's *system prompt*
  identified itself as **Claude Opus 4.8** (model id `claude-opus-4-8[1m]`),
  but the real usage breakdown reported by Claude Code's `/cost` command (see
  below) shows that the model actually billed for almost all of the work was
  **`claude-sonnet-5`**, with a small fraction on **`claude-haiku-4-5`** (used
  for web searches). This discrepancy is recorded as-is, with no attempt to
  reconcile it — it may be down to internal platform routing/fallback not
  visible from within the conversation.
- **Tool**: [Claude Code](https://claude.com/claude-code), Anthropic's official
  command-line agent, running in agentic mode with access to PowerShell, file
  editing and web search (not a plain chat: the agent itself installed
  software, edited GLSL shaders, read compiler logs, and created/pushed this
  git repository).
- **Date**: August 13, 2026.
- **Actual duration (exact `/cost` figure)**: **1h 40m 30s wall-clock time**
  (total session time), of which **54m 15s** was API compute time. Matches the
  earlier estimate made from log/git timestamps (≥1.5h).
- **Number of messages/prompts**: a manual count of the visible turns in the
  conversation comes to **~30 user messages** (including answers to the
  assistant's clarifying questions and one uploaded image), across **14
  commits** to this repository. This is an approximate count done by hand while
  reviewing the conversation, not an exact metric instrumented by the platform.
- **Commits in the repo**: 14, all in that same session (first commit at
  13:10:20, last at 13:46:09 by git timestamps — the actual work involved
  considerably more back-and-forth diagnosis in between that didn't always end
  up as a commit).
- **Code changes (exact `/cost` figure)**: 1,291 lines added, 561 lines removed
  in total during the session (includes iteration and reverts, not just the
  final state).
- **Cost and tokens (exact `/cost` figure)**: **$30.13** total.
  - `claude-sonnet-5`: 21.7k input tokens, 272.9k output tokens, 76.0 million
    cache-read tokens, 510.9k cache-write tokens ($30.03).
  - `claude-haiku-4-5`: 57.0k input tokens, 3.7k output tokens, no cache usage,
    3 web searches ($0.1057).
  - Most of the token volume is cache reads (cheap per token), which is why
    the total cost stayed moderate ($30) despite tens of millions of tokens
    processed overall — typical of a long session where the conversation
    history gets served from cache turn-to-turn instead of being reprocessed
    from scratch.

Honest notes on the process, not marketing:

- All three CRT shaders had **real bugs** when adapted (black screen, then blue,
  then no effect at all) that were diagnosed by reading mpv/Jellyfin Media
  Player's actual shader compile logs, not guesswork. There were three distinct
  root causes (a `#define` colliding with a struct field name, `linearize`/
  `delinearize` not being native to `vo=gpu`, and double gamma correction in the
  passthrough path) — see the commit history for the detail on each.
- The first attempt at an automated test (`--vo=image`) turned out to be a
  **false positive**: it doesn't run the real GPU shader pipeline at all. This
  was caught by deliberately feeding it a broken shader and seeing it "pass"
  with no error. The correct method (real `--vo=gpu` + a screenshot via a Lua
  script) is documented and scripted in [docs/TESTING.md](docs/TESTING.md) and
  `test/test-shaders.ps1`, with a self-check that runs that same broken shader
  to confirm the harness actually catches errors before trusting it.
- The README screenshots were generated programmatically (real mpv `--vo=gpu` +
  a Lua script that takes the screenshot and quits), not manually cropped
  screen captures.

## Legal disclaimers

This is a personal/hobby project, not affiliated with or endorsed by Jellyfin,
mpv, libretro/RetroArch, or the rights holders of any audiovisual content shown
in the screenshots.

- **Shaders** (`assets/shaders/*.glsl`): these are adaptations/derivatives of
  third-party CRT shaders — see the credits section below. The upstream
  repository ([hhirtz/mpv-retro-shaders](https://github.com/hhirtz/mpv-retro-shaders))
  states that "each shader is under a different license, see their source for
  details," and the auto-generated files adapted here (`crt-aperture.glsl`,
  `crt-hyllian.glsl`) didn't carry an explicit license header. The exact license
  of each original algorithm was not exhaustively verified beyond what's visible
  in the repos mentioned — if you plan to redistribute or use this commercially,
  check each shader's license at its original source first. This repo's MIT
  license covers the original code (the launcher, `mpv.conf`, and the
  modifications made to the shaders — the screen-area clipping, the `#define` to
  `const float` change, and the `linearize`/`delinearize` fallbacks); it does
  **not** relicense each author's original CRT algorithm.
- **`assets/images/tv_frame.png`** (TV frame): an **AI-generated** image (Google
  Gemini), retouched afterwards. It does not derive from any copyrighted photograph,
  and the brand shown on the panel is fictional. Lacking human authorship, this
  repo's MIT license covers the code and claims no rights over this image.

## Credits and licenses

- The shaders `crt-lottes.glsl`, `crt-aperture.glsl` and `crt-hyllian.glsl` are adaptations of CRT shaders ported to mpv format by the [hhirtz/mpv-retro-shaders](https://github.com/hhirtz/mpv-retro-shaders) project (using the `mpv-libretro` tool) from original shaders in [libretro/glsl-shaders](https://github.com/libretro/glsl-shaders), originally created by Timothy Lottes (crt-lottes), Hyllian (crt-hyllian) and other contributors from the libretro/RetroArch community. Each shader retains its original copyright header where available in the source. See the repositories mentioned for each shader's license details.
- The `tv_frame.png` image was AI-generated (Google Gemini) and retouched by this repository's author (see Legal disclaimers above).
- This repository's original code (`launcher.ps1`, the `.bat`, the screen-area clipping changes to the shaders, `mpv.conf`) is distributed under the MIT license (see `LICENSE`).
