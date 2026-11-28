# Homebrew tap for Wingmate

```bash
brew tap kera77/wingmate
brew trust kera77/wingmate   # Homebrew 7 asks to trust third-party taps
brew install --cask wingmate
```

The cask always installs the latest [Wingmate release](https://github.com/Kera77/Wingmate/releases).
Wingmate updates itself afterwards (Settings › About).

## Installed as `dynotch` before?

The app used to be called Dynotch. Its own update already replaced `Dynotch.app` with
`Wingmate.app`, so `brew upgrade` stops with "App source '/Applications/Dynotch.app' is not there".
Move Homebrew's record over once:

```bash
brew update
brew trust kera77/wingmate
rm -rf "$(brew --prefix)/Caskroom/dynotch"            # only Homebrew's record; the app stays
brew install --cask --adopt kera77/wingmate/wingmate  # takes over the Wingmate.app already there
```

The cask is kept in the main repository under `Packaging/Homebrew` and copied here.
