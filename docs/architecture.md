# Architecture

How star-history-action works, end to end.

## 1. Trigger to job

```
   ┌───────────────┐      ┌────────────────────┐      ┌─────────────────────┐
   │   schedule    │      │  workflow_dispatch │      │  push (optional,    │
   │   cron 6h     │      │  manual run button │      │  discouraged)       │
   └───────┬───────┘      └─────────┬──────────┘      └──────────┬──────────┘
           │                        │                            │
           └────────────────────────┼────────────────────────────┘
                                     ▼
                    ┌────────────────────────────────┐
                    │  GitHub Actions runner (job)    │
                    │  permissions: contents: write   │
                    │  concurrency: serialize runs    │
                    └───────────────┬─────────────────┘
                                    ▼
                    ┌────────────────────────────────┐
                    │  uses: narayann7/               │
                    │        star-history-action@v1   │
                    └───────────────┬─────────────────┘
                                    ▼
                          (composite steps, section 2)
```

## 2. Composite action steps

```
   ┌──────────────────────┐
   │ actions/checkout      │  consumer step, runs before the action
   └──────────┬───────────┘
              ▼
   ┌──────────────────────┐
   │ setup-node (Node 24)  │
   └──────────┬───────────┘
              ▼
   ┌──────────────────────────────┐
   │ npm ci  (renderer deps)       │  jsdom, d3, svgo, axios, tsx ...
   └──────────┬───────────────────┘
              ▼
   ┌──────────────────────────────┐
   │ RENDER + CHANGE DETECTION     │  (section 3 + 4)
   │ tsx render.ts                 │
   └──────────┬───────────────────┘
              │
        changed?
         ┌────┴─────┐
     No  │          │  Yes
         ▼          ▼
   ┌──────────┐   ┌───────────────────────────┐
   │  exit    │   │ UPDATE README              │
   │ no commit│   │ rewrite first marker pair  │
   └──────────┘   │ <!-- star-history:start -->│
                  └────────────┬───────────────┘
                               ▼
                  ┌───────────────────────────┐
                  │ COMMIT + PUSH              │
                  │ github-actions[bot]        │
                  │ rebase then push (or fail) │
                  └────────────┬───────────────┘
                               ▼
                        chart lives in repo
```

## 3. render.ts pipeline (per theme)

```
   ┌─────────────────────────────┐
   │ parse args (repos, theme,   │   token from GITHUB_TOKEN env only
   │ type, width, output, sig)   │
   └──────────────┬──────────────┘
                  ▼
   ┌─────────────────────────────┐        ┌──────────────────────────┐
   │ getRepoData(repos, token)   │ ─────► │  GitHub stargazers API    │
   │ (vendored star-history code)│ ◄───── │  api.github.com/.../stargazers
   └──────────────┬──────────────┘        └──────────────────────────┘
                  ▼
   ┌─────────────────────────────┐
   │ signature = sha256 of star  │   day-level dates + counts
   │ data  ──► write --signature │   (used for change detection)
   └──────────────┬──────────────┘
                  ▼
   ┌─────────────────────────────┐
   │ JSDOM <svg> +               │
   │ convertDataToChartData +    │   draw the chart into the svg node
   │ XYChart(..., envType:node)  │
   └──────────────┬──────────────┘
                  ▼
   ┌─────────────────────────────┐        ┌──────────────────────────┐
   │ inline external <image>     │ ─────► │  owner avatar (image/*,   │
   │ as base64 (<=2MB, image/*)  │ ◄───── │  <=2MB, else dropped)     │
   └──────────────┬──────────────┘        └──────────────────────────┘
                  ▼
   ┌─────────────────────────────┐
   │ strip <style>/@font-face    │   GitHub strips it anyway; also
   │ and .browser-only nodes     │   removes the only non-MIT font
   └──────────────┬──────────────┘
                  ▼
   ┌─────────────────────────────┐
   │ fix JSDOM casing + svgo      │
   │ optimize ──► write .svg      │
   └─────────────────────────────┘
```

## 4. Change detection (why it does not commit every run)

```
                 ┌───────────────────────────────┐
                 │ render probe theme             │
                 │ ──► new signature (star data)  │
                 └───────────────┬───────────────┘
                                 ▼
                 ┌───────────────────────────────┐
                 │ read stored .star-history.sig  │
                 └───────────────┬───────────────┘
                                 ▼
                        new sig == old sig ?
                          ┌──────┴───────┐
                     Yes  │              │  No (stars changed
                          ▼              ▼   or day rolled over)
              ┌────────────────┐   ┌──────────────────────────────┐
              │ changed=false  │   │ render remaining themes       │
              │ keep files     │   │ new timestamp <YYYYMMDDHHMMSS>│
              │ NO commit      │   │ delete old timestamped files  │
              └────────────────┘   │ write new .star-history.sig   │
                                   │ changed=true                  │
                                   └──────────────────────────────┘
```

The SVG itself has sub-pixel float jitter between runs, so comparing rendered
files would always look changed. Comparing the star data (dates + counts, day
granularity) instead means a commit only happens when the chart really moves.

## 5. Data provenance

```
   your repo's stargazers  ──►  GitHub API  ──►  render.ts  ──►  SVG in your repo
        (owner/collab                                   │
         access only)                                   └─► README <picture> block
```

- Token: `${{ github.token }}` reads your own repo's stargazers. A PAT is needed
  only to chart a repo the default token cannot read.
- The SVG embeds the repository owner's avatar and the chart. It does not embed
  any individual stargazer's identity.

## Components

| Piece | Role |
|---|---|
| `action.yml` | composite action: install, render, change-detect, update README, commit |
| `renderer/render.ts` | wrapper that drives the vendored renderer and emits the signature |
| `renderer/vendor/shared` | star-history's own chart code (MIT, pinned commit) |
| `.star-history.sig` | stored data signature, gates commits |
| `star-history-<theme>-<ts>.svg` | committed chart; timestamp busts GitHub's image cache |
| marker comments | where the action writes the `<picture>` block in the README |
```

