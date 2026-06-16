# Homebrew Tap for NornicDB

This directory is structured as the future `orneryd/homebrew-nornicdb` tap repository.

## Install

```bash
brew tap orneryd/nornicdb
brew install nornicdb
```

During `brew install`, the formula runs a first-run setup wizard from
`post_install`. It asks for the same normal choices as the macOS first-run
wizard:

- Basic, Standard, or Advanced profile
- Authentication settings
- Optional database encryption
- Optional local GGUF model downloads

The generated configuration is written to:

```text
$(brew --prefix)/etc/nornicdb/config.yaml
```

If Homebrew is running without an interactive terminal, the formula writes a
safe Standard configuration with authentication disabled. Re-run the wizard
interactively with:

```bash
rm "$(brew --prefix)/etc/nornicdb/config.yaml"
brew postinstall nornicdb
```

## Run as a Service

```bash
brew services start nornicdb
```

The service stores data in:

```text
$(brew --prefix)/var/nornicdb
```

Logs are written to:

```text
$(brew --prefix)/var/log/nornicdb
```

Local models are stored in:

```text
$(brew --prefix)/var/nornicdb/models
```

The service starts NornicDB with:

```bash
nornicdb serve --config "$(brew --prefix)/etc/nornicdb/config.yaml"
```

## Formula Maintenance

Tagged NornicDB releases are expected to publish:

- `nornicdb-darwin-arm64.tar.gz`
- `nornicdb-darwin-amd64.tar.gz`
- `SHA256SUMS`

Update the formula after a release:

```bash
./scripts/update-formula.sh v1.1.6 /path/to/SHA256SUMS
```

Then run:

```bash
brew audit --strict --online Formula/nornicdb.rb
brew test Formula/nornicdb.rb
```
