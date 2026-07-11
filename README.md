# Star History Action

Keep a self-updating star history chart in **your own** repository's README.

> **Unofficial.** This is a community project and is not affiliated with, endorsed by, or maintained by [star-history.com](https://www.star-history.com) or its team. It reuses their open-source renderer with credit (see [Credits](#credits)).

## Why

On June 30, 2026 GitHub limited its stargazers endpoint to a repo's own admins and collaborators. Since then the hosted `api.star-history.com/svg` badge renders blank for many repos, so live star-history README badges stopped working.

The access GitHub still allows is a repo's **owner or collaborator** reading **their own** repo's stargazers. This action leans on exactly that: it runs in your CI with your own access, renders the chart, and commits it into your repo (SVG, plus a PNG for package registries) so the README embeds a static file. It is meant for charting repositories you own or collaborate on. It does not scrape star-history.com and does not embed any individual stargazer's identity, only the repository owner's avatar.

The chart is drawn by [star-history's own renderer](https://github.com/star-history/star-history), vendored under `renderer/vendor` and run in Node, so the output matches star-history.com without a headless browser or a third-party CLI. See `renderer/NOTICE.md` for the pinned commit and attribution.

## Endorsement

The star-history maintainer pointed to this approach in the tracking issue, for anyone who would rather not hand a fine-grained token to the star-history API:

> If you are not comfortable to share your fine-grained token with star-history API, then @narayann7's method is good (the tradeoff is it's a static image, though you can configure a cron to refresh it periodically).
>
> star-history/star-history#539: https://github.com/star-history/star-history/issues/539#issuecomment-4896077391

## Demo

This repo runs the action on itself; the chart below is the real, self-updating output. On any repo the action replaces the block between the marker comments with a live chart on its first run and keeps it current on whatever triggers you configure. This repo's own chart refreshes when the repo gains a star.

<!-- star-history:start -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/star-history/star-history-dark.svg">
  <img alt="Star history" src="assets/star-history/star-history-light.svg">
</picture>
<!-- star-history:end -->

## How it works

```
  schedule / new star / manual dispatch
             │
             ▼
  ┌────────────────────────────────────┐
  │  GitHub Action (runs in your CI)    │
  │                                      │
  │  render chart ──► changed?           │
  │       │                              │
  │       ├─ yes ─► commit SVG           │
  │       │         + update README      │
  │       └─ no  ─► do nothing           │
  └──────────────────┬───────────────────┘
                     ▼
      README <picture> shows the chart
```

The action renders the chart with your own token, and commits it only when the
star data actually changes. For the full flow, the `render.ts` pipeline, and the
change-detection logic, see [docs/architecture.md](docs/architecture.md).

## Usage

Add `.github/workflows/star-history.yml`:

```yaml
name: Star History

on:
  schedule:
    - cron: '0 */6 * * *'   # every 6 hours; see the interval table below
  watch:
    types: [started]        # optional: also refresh right after a new star
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: star-history
  cancel-in-progress: false

jobs:
  star-history:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: narayann7/star-history-action@v1
        with:
          repos: ${{ github.repository }}   # the current repo; or a list like owner/repo,owner/repo2
```

> **Recommended cadence: a scheduled run every 3h, 6h, or once a day.** Star
> counts move slowly, so anything more frequent just burns CI minutes and adds
> noise. Avoid the 5-minute cron (it exists only for quick testing) and avoid a
> `push` trigger: pushing on every commit re-runs the job constantly and adds
> churn for no benefit. Pick a schedule and let it run.

Then add these two marker comments to your README where you want the chart:

```html
<!-- star-history:start -->
<!-- star-history:end -->
```

Leave them empty. On each run the action fills the space between them with the
current chart and updates it when the chart changes:

```html
<!-- star-history:start -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/star-history/star-history-dark.svg">
  <img alt="Star history" src="assets/star-history/star-history-light.svg">
</picture>
<!-- star-history:end -->
```

Files use stable names (`star-history-light.svg`, `star-history-dark.svg`,
`star-history.png`) and are overwritten in place. A fixed path matters for
package registries: npm and pub.dev freeze a README's image URL, so a moving
filename would 404 once the old file is deleted. On GitHub the chart still
refreshes, because a push purges GitHub's image cache for that path. The
`<picture>` block also swaps the dark chart in automatically on GitHub's dark
theme.

If your README is also published to npm or pub.dev, set `readme-format: png`.
Those sites strip `<picture>` and do not render SVG, so the action instead
writes a plain-markdown PNG at an absolute `raw.githubusercontent.com` URL,
which they can display. The tradeoff is a single PNG with no dark/light swap.

If you would rather manage the embed yourself, set `update-readme: false` and
point a plain `<img>` at whatever the action writes.

## Inputs

| input | default | description |
|---|---|---|
| `repos` | current repo | Comma-separated `owner/repo` list. |
| `output-dir` | `assets/star-history` | Where the chart files (SVGs and the PNG) are written. |
| `token` | `${{ github.token }}` | Token for the stargazers API. |
| `type` | `Date` | `Date` or `Timeline`. |
| `themes` | `light,dark` | Comma list of themes to render. |
| `width` | `800` | Image width in pixels. |
| `font-family` | `` | Optional [Google Fonts](https://fonts.google.com/) family applied to the PNG chart (e.g. `Patrick Hand`). Empty uses the bundled Comic Neue. |
| `update-readme` | `true` | Rewrite the README between the `star-history` marker comments to point at the newest chart. |
| `readme` | `README.md` | Path to the README to update. |
| `readme-format` | `picture` | Embed style: `picture` (SVG `<picture>`, GitHub dark/light) or `png` (plain-markdown absolute-URL PNG that also renders on npm and pub.dev). |
| `commit` | `true` | Commit and push the generated files. |
| `commit-message` | `chore: update star history [skip ci]` | Message used when committing. |

Outputs: `files` (newline-separated generated paths), `changed` (`true`/`false`), `light` and `dark` (the newest SVG paths), and `png` (the PNG path).

### Notes

> **Fonts:** GitHub strips `@font-face` from SVGs it serves through `<img>`/`<picture>`, so a custom font only renders in the PNG output (`readme-format: png`), not the SVG. Set `font-family` to any Google Fonts name to restyle the PNG. The action downloads the font, reads its real internal name so it renders even when that differs from the family string, and applies it. If the download fails, it falls back to the bundled Comic Neue and the run still succeeds. Non-Latin families (for example `Noto Sans SC`) work too, though single-weight fonts render the title in the regular weight since no bold face exists.

## Triggers

The recommended workflow uses these triggers:

- **schedule** runs the chart on a fixed cadence. This is the one you want, and it is strongly recommended: only the schedule refreshes the chart's time axis on days with no star change, and only it can pick up unstars. A repo that leaves it out (as this one does, running on `watch` alone to keep the demo minimal) accepts that its chart will not refresh on quiet days or reflect an unstar.
- **watch / started** (optional) runs the chart right after someone stars the repo, so a new star shows up without waiting for the next scheduled run. It fires on new stars only, never on unstars, so it supplements the schedule rather than replacing it. Mind the churn: because change-detection commits whenever the star count moves, stars that arrive spread out over time each get their own run and their own commit, while stars that land in a tight burst coalesce (the `concurrency` group keeps the latest run and cancels the superseded ones). Either way every run spends CI minutes, so a repo that gets stars in volume should prefer the schedule alone. For this trigger to fire, the workflow file must be on your repository's default branch.
- **workflow_dispatch** gives you a manual run button for the first run and ad-hoc refreshes.

A `push` trigger is also technically possible but **not recommended**: it re-runs the job on every commit, which wastes CI minutes and adds commit churn without meaningfully fresher data.

### Cron intervals

Swap the `cron` line for whichever cadence fits. All times are UTC.

| interval | cron | recommended |
|---|---|---|
| 5m | `*/5 * * * *` | no, testing only |
| 1h | `0 * * * *` | rarely |
| 3h | `0 */3 * * *` | yes |
| 6h | `0 */6 * * *` | yes (default) |
| 12h | `0 */12 * * *` | yes |
| daily | `0 0 * * *` | yes |
| weekly | `0 0 * * 0` | fine |

**Pick 3h, 6h, or daily.** Star counts move slowly, so that range is plenty. The 5-minute option is only for testing the setup; leaving it on burns CI minutes for identical charts. GitHub's minimum interval is 5 minutes anyway, scheduled runs fire approximately rather than on the dot, and a repo with no activity for 60 days has its scheduled runs paused.

## Token

The default `${{ github.token }}` is the automatic token GitHub injects into every workflow run, scoped to the repo the workflow lives in. For your own repo that satisfies the stargazers restriction, so **most users need no personal token at all**.

Only if a run fails as unauthorized (for example when charting a repo the default token cannot read) supply a personal access token through the `token` input from a secret:

```yaml
        with:
          token: ${{ secrets.GH_PAT }}
```

When you do need one, use the **least privilege that works**: a classic token with only the `public_repo` scope, or a fine-grained token with read-only access limited to the repositories you chart. Do not use a broad `repo`/`workflow` token. A token with no scopes does not work against the stargazers endpoint.

The `token` input is used **only to read stargazers**. The commit and push are authorized by the credentials `actions/checkout` persists (the workflow's default `GITHUB_TOKEN`), which is why `permissions: contents: write` is required. A PAT you pass here does not authorize the push. One consequence: because the push uses the default token, it does not trigger other `on: push` workflows, and it can be rejected on a branch with required status checks.

## Limitation

Charts need a token that can read the repo's stargazers. Your own repos always work with the default `${{ github.token }}`, and most other public repos work with a personal access token. GitHub's stargazers restriction can still block some repos, and when it does the chart comes back empty with no workaround.

## Credits

The chart rendering is powered by [star-history](https://github.com/star-history/star-history) (MIT). Their chart code is vendored under `renderer/vendor` and does all the real work of turning stargazer data into an SVG. This action is a thin wrapper that runs it in CI and commits the result. Thanks to the star-history maintainers.

## License

This project is MIT. See [LICENSE](./LICENSE).

It bundles star-history's code under `renderer/vendor`, which is also MIT. That license is kept intact at [`renderer/vendor/LICENSE`](./renderer/vendor/LICENSE), with attribution and the pinned commit in [`renderer/NOTICE.md`](./renderer/NOTICE.md).
