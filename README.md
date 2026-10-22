# PyfaNix

A lean and modern Nix Flake for building, installing, and running [Pyfa (Python Fitting Assistant)](https://github.com/pyfa-org/Pyfa) for EVE Online across Linux and macOS architectures.

---

## Features

- **Multi-Architecture Support (`forAllSystems`)**: Automatically builds and installs for the host machine's architecture (`x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`) using standard Nixpkgs primitives without extra flake helper dependencies.
- **Full Desktop Integration**: Installs standard XDG `.desktop` entries and application icons (`$out/share/applications` and `$out/share/icons`), ensuring Pyfa shows up in application launchers (GNOME, KDE, Rofi, etc.).
- **Ready Out-of-the-Box (Pre-built Database)**: The static EVE game database (`eve.db`, ~97 MB) is compiled during the Nix build phase. Eliminates first-launch freezes and avoids crashes caused by the read-only Nix store.
- **Dark Mode / Theme Compatibility Patch**: Bridges a version gap between Pyfa's git-master codebase and stable wxPython in Nixpkgs.

---

## Usage with the Nix CLI

### 1. Run Directly (Without Installation)
From the local checkout:
```bash
nix run .
```
Or directly from GitHub:
```bash
nix run github:3DIRK/PyfaNix
```

### 2. Install to User Profile
```bash
nix profile install .
```
*(Pyfa is now available as `pyfa` in your `$PATH` and inside your desktop environment's application launcher.)*

### 3. Build Locally
```bash
nix build
```
The resulting build will be linked at `./result/`.

### 4. Update Sources
Since this flake tracks the latest rolling development branch (`master`) of Pyfa:
```bash
nix flake update
```

---

## Integration into NixOS

You can integrate Pyfa into your NixOS system configuration using either of the following approaches:

### Option A: Direct Package Reference (Recommended)

Add the flake to your system `inputs` in your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyfa-nix.url = "github:3DIRK/PyfaNix";
  };

  outputs = { self, nixpkgs, pyfa-nix, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          environment.systemPackages = [
            pyfa-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
          ];
        }
      ];
    };
  };
}
```

---

### Option B: Via Overlay

If you prefer referencing Pyfa transparently like any other Nixpkgs package (`pkgs.pyfa`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyfa-nix.url = "github:3DIRK/PyfaNix";
  };

  outputs = { self, nixpkgs, pyfa-nix, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [ pyfa-nix.overlays.default ];
          environment.systemPackages = [ pkgs.pyfa ];
        }
        ./configuration.nix
      ];
    };
  };
}
```

---

## Technical Details & Architecture

### 1. Dark Mode & Theme Patching

#### The Issue
In Pyfa's git-master branch, a new theming function was introduced in `gui/utils/dark.py`:
```python
appearance = {
    ThemeSettings.SYSTEM: wx.App.Appearance.System,
    ThemeSettings.DARK: wx.App.Appearance.Dark,
}.get(theme, wx.App.Appearance.Light)
app.SetAppearance(appearance)
```
The `wx.App.Appearance` enum and `SetAppearance()` method require the unreleased **wxWidgets 3.3 / wxPython 4.3** toolchain (currently in active pre-release development). Nixpkgs ships stable **wxPython 4.2.5** (built against wxWidgets 3.2.11). On launch, Pyfa previously crashed with:
```text
AttributeError: type object 'App' has no attribute 'Appearance'
```

#### The Fix in the Flake
In `flake.nix`, the call is safely neutralized during `postPatch`:
```nix
postPatch = ''
  substituteInPlace gui/utils/dark.py \
    --replace-fail "app = app or wx.GetApp()" "return False"
'';
```

#### Does Dark Mode Still Work on Linux?
**Yes, completely.**
- Upstream introduced `app.SetAppearance()` specifically to experiment with Win32 dark mode controls on Windows 10/11.
- On **Linux (GTK3)**, Pyfa determines the system theme through `wx.SystemSettings.GetAppearance().IsDark()`, which is fully implemented in wxPython 4.2.5.
- Backgrounds, text contrast, fitting grids, and GTK3 native widgets automatically respect your desktop's light or dark mode theme (e.g. Adwaita-dark, Breeze-Dark) without issues.

---

### 2. Pre-generating the Game Database (`eve.db`)

Pyfa requires a static SQLite database (`eve.db`) containing item IDs, dogma attributes, and fitting mechanics.

- If missing, Pyfa invokes `db_update.py` on startup to generate `eve.db` in its installation directory.
- Because the Nix store (`/nix/store/...`) is strictly read-only, attempting to write `eve.db` at runtime results in an SQLite operational error.
- **Solution in the Flake**: During `buildPhase`, `python db_update.py` runs once while the build directory is writable. The generated database (~97 MB) is placed directly in `$out/share/pyfa/eve.db`. User data, saved fits, and custom settings remain isolated in `~/.pyfa/` as expected.

---

## License

This Flake is distributed under the [MIT License](LICENSE).  
Pyfa itself is licensed under the [GNU General Public License v3.0](https://github.com/pyfa-org/Pyfa/blob/master/LICENSE).
