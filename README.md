# alecdwm/homebrew-tap

Homebrew casks for software by [alecdwm](https://github.com/alecdwm).

```sh
brew tap alecdwm/tap
```

## Casks

| Token | What it installs | Source |
|---|---|---|
| `sshdrive` | SSH Drive: mounts SFTP locations in Finder through the File Provider framework, driven by the `sshdrive` command-line tool. No GUI. | [alecdwm/sshdrive](https://github.com/alecdwm/sshdrive) |

## SSH Drive

Requires macOS 14 or later on Apple silicon or Intel. The DMG is Developer ID
signed and notarized.

```sh
brew install --cask sshdrive
sshdrive add nas user@nas.example.com --remote-path /volume1
```

Installing does three things: copies `SSH Drive.app` into `/Applications`,
symlinks the `sshdrive` command into Homebrew's `bin`, and launches the app once
in the background so macOS registers its File Provider extension and its
background agent. You will see two pieces of system UI and no others:

- Gatekeeper's one-time "downloaded from the internet" dialog the first time the
  app opens.
- The "Background Items Added" notification. The item is already enabled; there
  is nothing to switch on in System Settings.

On the first connection to a server on your local network, macOS also asks
whether SSH Drive may find devices on the local network. Answer yes for LAN
servers; the prompt does not appear for hosts reached over the internet or a
VPN.

### Upgrading

```sh
brew upgrade --cask sshdrive
```

Mounted locations, cached files and pending uploads survive an upgrade. The
agent is stopped, the bundle replaced, and the login item re-registered without
a logout.

### Uninstalling

Remove your locations first. Homebrew cannot remove File Provider domains or
keychain items on your behalf, and a domain left behind keeps an empty folder
under `~/Library/CloudStorage`.

```sh
sshdrive remove --all
brew uninstall --cask sshdrive
```

`brew uninstall --zap --cask sshdrive` additionally deletes the app group
container with its index and configuration.

## Maintaining this tap

- The file name is the cask token: `Casks/sshdrive.rb` is what
  `brew install --cask sshdrive` resolves. The token matches the command it
  installs and the source repository, all `sshdrive`.
- Each SSH Drive release is built and notarized by `scripts/release.sh` in the
  source repository, which prints the `version` and `sha256` lines for the cask.
  Update those two lines here for each release; the DMG is attached to the
  matching GitHub release in `alecdwm/sshdrive`.
- Before announcing a release, run the checks Homebrew provides:

  ```sh
  brew style alecdwm/tap
  brew audit --new --cask alecdwm/tap/sshdrive
  ```

- The cask's `uninstall` stanza signals the launchd label
  `org.shirls.sshdrive.agent`, not the bundle id, because Homebrew matches the
  string against `launchctl list`, where only the label appears.
