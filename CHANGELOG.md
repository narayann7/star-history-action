# Changelog

All notable changes to this action are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-07-11

### Added
- PNG output. The renderer now rasterizes a `star-history.png` alongside the
  SVGs, so the chart shows on registries that cannot render SVG (npm, pub.dev).
- `readme-format` input (`picture` or `png`). `picture` keeps the SVG
  `<picture>` block with GitHub dark/light support; `png` writes a plain
  Markdown image at an absolute `raw.githubusercontent.com` URL, which is the
  form that renders on npm and pub.dev.

### Changed
- Stable filenames. Charts are written to fixed paths
  (`star-history-<theme>.svg`, `star-history.png`) and overwritten in place
  instead of timestamped names. A frozen README URL on a registry no longer
  404s when a new chart is generated.
- The action's own repository now demos with a static placeholder and no longer
  commits its live chart into git.

### Fixed
- PNG rasterization stripped the decorative `feTurbulence`/`feDisplacementMap`
  sketch filter, which crashed the raster engine (resvg). The SVG output keeps
  the filter; only the PNG drops it.

### Compatibility
- Repositories upgrading from 1.0.0 keep their old timestamped files. Those are
  left in place so any already published registry README that points at the old
  URL still resolves. The action stops producing timestamped names but does not
  delete existing ones.
- On the first run after upgrade, the chart is regenerated even when the star
  count is unchanged, so the new stable files and the PNG are created once.

## [1.0.0] - 2026-07-06

### Added
- Initial release. Composite GitHub Action that renders a star history chart in
  the repository's own CI, where the token can still read its own stargazers,
  and commits the chart into the repo so the README embeds a static file.
- Chart rendering via star-history's own renderer, vendored under
  `renderer/vendor` and run in Node with JSDOM and svgo. No headless browser and
  no third-party CLI.
- Light and dark SVG themes, embedded via a `<picture>` block between
  `<!-- star-history:start -->` and `<!-- star-history:end -->` markers.
- Change detection by star data signature, so a run only commits when the stars
  actually move or the day rolls over.
- Triggers for push, cron schedule, and manual dispatch, with a documented
  own-repos scope and PAT guidance for repos the default token cannot read.

[1.0.1]: https://github.com/narayann7/star-history-action/releases/tag/v1.0.1
[1.0.0]: https://github.com/narayann7/star-history-action/releases/tag/v1.0.0
