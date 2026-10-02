# Gameplay sound effects

Original synthesized cues, generated with `python tools/build_gameplay_audio.py`.
No external samples or dependencies. All three are mono, 48 kHz, 16-bit PCM WAV,
with short edge fades and approximately 3 dB peak headroom.

| File | Length | SoundService object | Character |
| --- | --- | --- | --- |
| `level-up.wav` | 1.05 s | `LevelUp` | Rising four-note bell flourish |
| `dash.wav` | 0.30 s | `Dash` | Fast filtered-air whoosh with a falling tone |
| `upgrade-choose.wav` | 0.48 s | `UpgradeChoose` | Crisp click and two ascending chimes |

## Activate in Roblox

The uploaded audio is configured in `default.project.json`:

| SoundService object | Asset ID |
| --- | --- |
| `LevelUp` | `140365393752838` |
| `Dash` | `126195029759598` |
| `UpgradeChoose` | `126535972501908` |

Restart `rojo serve`, reconnect the plugin, and restart Play to apply the mapping.
The experience must have permission to use these audio assets.
For replacement uploads:

1. Import the three WAVs through Studio's Asset Manager or Creator Dashboard.
2. Grant the experience permission to use the uploaded audio and wait for moderation.
3. Set each `tree.SoundService.<object>.$properties.SoundId` in
   `default.project.json` to its `rbxassetid://<uploaded ID>`.
4. Restart `rojo serve`, reconnect the plugin, and restart Play. For a standalone
   place, run `rojo build -o Test.rbxlx` and reopen it.

See [Roblox's audio import guide](https://create.roblox.com/docs/audio/assets).
Until configured, each missing cue logs one warning per client session and skips
playback. Existing revolver and kill-confirmation audio is unchanged.

## Playback and Studio checks

- Level-up plays locally when replicated Level increases. Initial HUD mount,
  ordinary XP gains, death/reset, and respawn do not celebrate a level-up.
- Upgrade choice plays locally when the server-confirmed inventory transition
  selects a card, synchronized with its exit animation. Rejected requests,
  repeated keys/taps, and subsequent updates during that animation do not replay it.
- Dash plays from the dashing character's root after the existing server broadcast,
  for nearby listeners, fading out by 75 studs. The sound is reused across dashes
  and destroyed with the character effect on death/removal.

In Studio, level up, pick with keyboard and touch, exhaust dash charges, and
respawn. With two players, verify private progression cues and audible nearby
dashes; rejected dashes should be silent. Check the mix alongside gunfire and
kill confirmation. These listening and multiplayer checks must be run in Studio.
