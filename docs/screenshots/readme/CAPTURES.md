# Android screenshot provenance

Captured on 2026-11-05 by navigating the running Android app in Dark mode.
Every PNG is an unaltered native `adb exec-out screencap -p` capture. No widget-test rendering, injected state, fixture catalogue, generated
placeholder artwork or constructed AI replies were used.
The capture device runs Android 12 with software rendering. Phone captures are
1080 × 2340 at 420 dpi; wide captures are 1920 × 1200 at 240 dpi. Temporary
display overrides were restored afterward. Existing app data was preserved.

## Real acquisition and navigation

- In Discover → Chub, searched for **Isekai RPG** and downloaded **Isekai RPG**
  and **Isekai RPG V2 (WIP)**. Their actual artwork and attached lorebooks came
  from the live source through the app's Download action.
- Opened a new chat with the imported card and selected its third bundled
  greeting with the greeting arrows. The greeting is supplied by that card;
  it is not a newly generated assistant response.
- For the Gallery, exported an app backup through Settings → Backups → Export.
  Extracted only the two unchanged picture files belonging to those real
  downloads, placed them in the device's image picker, and added them through
  Gallery's Android picker and naming flow. Both new Gallery records are owned
  by the newly downloaded card. No records or database entries were injected.
  The private backup itself is not part of this repository.
- Used one downloaded picture through the new chat's Custom background → Files
  picker, then opened a blank `/btw` pane. The return tab shows the same wallpaper.
  No provider was configured, so the side conversation has no staged replies.
- Opened the imported character's **Open in Studio** action and switched to
  **Draft**. Its fields are the real downloaded card, not a seeded workspace.
- Added a separate Home page using the Home editor. It contains the new actual
  chat and ordinary Discover, Library, Gallery and Studio shortcuts. Earlier
  pages were retained and are not shown in the captures.

| File | Actual screen and content |
| --- | --- |
| `01-mobile.png` | Imported card's bundled greeting, alternative 3, in a new chat |
| `02-tablet.png` | The new Home page at wide display dimensions |
| `03-chat-tools.png` | That imported greeting beside a blank saved side conversation, with a downloaded wallpaper |
| `04-agentic-studio.png` | The imported card opened in Studio's Draft editor |
| `05-discover.png` | Live Chub results for the Isekai RPG search |
| `06-home.png` | The new Home page on the phone display |
| `07-library.png` | The real lorebook obtained with the downloaded card |
| `08-gallery.png` | The two unchanged downloaded pictures, imported with the real picker and naming sheet |

No generated demo content, provider keys, private account details, backup
archives, device identifiers or machine paths are included in these photos.
