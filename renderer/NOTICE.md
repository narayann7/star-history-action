# Vendored code attribution

`vendor/shared/` is copied verbatim from the star-history project:

- Source: https://github.com/star-history/star-history
- Pinned commit: `fb8e1078c9e48c612f830f2cb6c36e046a6697d5`
- License: MIT (see `vendor/LICENSE`)

`render.ts` reproduces the SVG generation flow from that project's
`backend/main.ts`, and the `fixJsdomSvgCasing` helper is copied from its
`backend/utils.ts`.

To update the vendored code, re-copy `shared/` from a newer star-history commit
and bump the pinned commit above.
