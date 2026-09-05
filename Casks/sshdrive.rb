cask "sshdrive" do
  version "0.1.0"
  sha256 "be1c283d952413affab846ae2be8add8acab706d589081e57019738f9ae6a16f"

  url "https://github.com/alecdwm/sshdrive/releases/download/v#{version}/SSH-Drive-#{version}.dmg"
  name "SSH Drive"
  desc "Mount SFTP locations in Finder through the File Provider framework"
  homepage "https://github.com/alecdwm/sshdrive"

  # DESIGN.md section 2: minimum macOS 14. The symbol form is a minimum in current Homebrew.
  depends_on macos: :sonoma

  app "SSH Drive.app"

  # DESIGN.md section 10: the CLI is symlinked out of the bundle rather than installed
  # separately. It is a pure XPC client of the agent, so it works through any path,
  # including this symlink; it just cannot be the thing that registers the app.
  binary "#{appdir}/SSH Drive.app/Contents/MacOS/sshdrive"

  # Launching the app is what registers the File Provider extension with PlugInKit and the
  # login item through SMAppService, and both must be done from the app's own bundle
  # (section 10). macOS then posts its "background item added" notification, with the item
  # already enabled, and Gatekeeper shows its one-time downloaded-from-the-internet dialog
  # the first time the quarantined bundle is opened. Those are the only UI a user sees.
  #
  # The unregister first is not belt and braces. Homebrew deletes the old app and installs
  # the new one, and a login item whose bundle has been deleted and put back keeps its
  # enabled status while launchd can no longer resolve the program: every spawn fails with
  # "Could not find and/or execute program specified by service" on a 10 s retry, for ever,
  # and SMAppService.register() keeps returning success throughout because as far as it is
  # concerned the item is still enabled. Only unregister() clears it (S1 f2, 2026-09-04).
  # On a first install there is nothing to unregister and the call is a no-op.
  postflight do
    system_command "#{appdir}/SSH Drive.app/Contents/MacOS/SSH Drive",
                   env: { "SSHDRIVE_AGENT_ROLE" => "unregister" },
                   must_succeed: false
    system_command "/usr/bin/open",
                   args: ["-g", "#{appdir}/SSH Drive.app"],
                   must_succeed: false
  end

  # Homebrew runs `uninstall` on `brew upgrade` and `brew reinstall` as well as on
  # `brew uninstall`, so nothing destructive may live here (section 10).
  #
  # The label is `org.shirls.sshdrive.agent`, the launchd label of section 3.1, and not the
  # bundle id: Homebrew matches this string against `launchctl list` output, where only the
  # label ever appears (S1 g1, 2026-09-04). The agent handles TERM itself - it shuts every
  # location's ssh master down and exits 0, which is what keeps `KeepAlive` with
  # `SuccessfulExit` false from restarting it out of the bundle being replaced.
  #
  # Deliberately no `launchctl:` here. That directive boots the label out of launchd while
  # SMAppService and the background-task database still consider the login item enabled, so
  # the next launch would register "only if needed", do nothing, and leave the mach service
  # dead until the next login (section 10).
  uninstall signal: ["TERM", "org.shirls.sshdrive.agent"]

  # `zap` runs after the app has already been deleted, so nothing here can call
  # `sshdrive remove --all`: by this point there is no CLI and no provider left to call
  # NSFileProviderManager.remove(domain), which is why the caveats and `sshdrive doctor`
  # both say to run it first (section 10).
  #
  # `launchctl:` is right here, unlike in `uninstall`, because nothing is coming back.
  # The group container is where config.json, every domain's index.sqlite,
  # capabilities.json and pins.json live (section 3).
  #
  # What `zap` cannot reach, and what the caveats therefore have to say:
  #   - the keychain items. They live in the data-protection keychain under access group
  #     RWGDZAYBM8.org.shirls.sshdrive; no file removal reaches them and no cask directive
  #     addresses them. `sshdrive remove --all` is what deletes them, and skipping it
  #     leaves orphaned items that a later install's `add` simply overwrites.
  #   - the File Provider domains, and so the sidebar entries and the cached content under
  #     ~/Library/CloudStorage. Deleting those directories from here would throw away any
  #     upload the system still has pending, so they are left alone; the system drops them
  #     once it finds the provider gone, sometimes not before the next login.
  zap launchctl: "org.shirls.sshdrive.agent",
      trash:     [
        "~/Library/Group Containers/RWGDZAYBM8.org.shirls.sshdrive",
        "~/Library/Caches/org.shirls.sshdrive",
        "~/Library/HTTPStorages/org.shirls.sshdrive",
        "~/Library/Preferences/org.shirls.sshdrive.plist",
      ]

  caveats <<~EOS
    Add your first location with:

      sshdrive add nas alec@nas.example

    Two prompts to expect, both from macOS and neither avoidable:

      * "Background Items Added" - SSH Drive registered its login agent. It is
        already enabled; the notification is telling you, not asking you.

      * "Allow "SSH Drive" to find devices on local networks?" - the first time
        it connects to a server on your own network, which is the ordinary case
        for a NAS. Answer Allow, or the mount cannot reach it. If you miss it:
        System Settings > Privacy & Security > Local Network.

    Before uninstalling, run:

      sshdrive remove --all

    Homebrew cannot remove File Provider domains or keychain items for you, and
    by the time `brew zap` runs the app that could is already gone.
  EOS
end
