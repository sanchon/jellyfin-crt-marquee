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
   - Lets you pick: **CRT Lottes**, **CRT Aperture**, **CRT Hyllian**, just the TV frame with no shader, or disable everything (normal Jellyfin, no frame, no shader).
   - Opens Jellyfin Media Player automatically with the configuration applied.

To switch shaders later, repeat step 1 (running the launcher again is safe, it doesn't duplicate anything, and it handles closing/reopening JMP for you).

It's portable: you can copy the whole folder to another PC with Jellyfin Media Player installed, it doesn't depend on any particular Windows user.

## How it works (technical summary)

- `mpv.conf` uses `--lavfi-complex` to composite the video inside the screen cutout of the frame PNG (`external-file` instead of the `movie=` filter, because `movie=` doesn't handle Windows drive-letter paths well — a known ffmpeg/mpv bug).
- The screen cutout in the PNG was detected by analyzing the alpha channel (semi-transparent) with a flood-fill script: `X=36 Y=78 W=474 H=364` on a `670x473` image.
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

- **Model**: Claude Opus 4.8 (model id `claude-opus-4-8[1m]`).
- **Date**: August 13, 2026.
- **Commits in the repo**: 11, all in that same session (first commit at 13:10,
  last at 13:38 by git timestamps — the actual work involved considerably more
  back-and-forth diagnosis in between that didn't always end up as a commit).
- **Token cost / session price**: not something accessible from inside the
  conversation, so it hasn't been made up. If you're interested in that figure,
  it can be checked from the usage/billing dashboard of the Claude account that
  ran the session (it isn't exposed to the model itself).

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
- **`assets/images/tv_bezel.png`**: the TV frame image was provided by this
  repository's human author; its exact origin/license was not verified by the AI
  assistant that generated this project. If you hold the rights to this image and
  object to its use here, open an issue and it will be removed.

## Credits and licenses

- The shaders `crt-lottes.glsl`, `crt-aperture.glsl` and `crt-hyllian.glsl` are adaptations of CRT shaders ported to mpv format by the [hhirtz/mpv-retro-shaders](https://github.com/hhirtz/mpv-retro-shaders) project (using the `mpv-libretro` tool) from original shaders in [libretro/glsl-shaders](https://github.com/libretro/glsl-shaders), originally created by Timothy Lottes (crt-lottes), Hyllian (crt-hyllian) and other contributors from the libretro/RetroArch community. Each shader retains its original copyright header where available in the source. See the repositories mentioned for each shader's license details.
- The `tv_bezel.png` image was provided by this repository's author (see Legal disclaimers above).
- This repository's original code (`launcher.ps1`, the `.bat`, the screen-area clipping changes to the shaders, `mpv.conf`) is distributed under the MIT license (see `LICENSE`).
