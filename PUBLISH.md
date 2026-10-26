# Publishing `almata-ai/veilcc-protect` to the GitHub Marketplace

This repo is the standalone VeilCC GitHub Action. It's a thin client of your
Protection API (no sealing IP, no secrets — it posts the user's own object + their
own API key), so it is meant to be **public**.

## Public or private?

**Public.** Two hard reasons:

1. **The Marketplace only accepts public repos.** You can't list a private action.
2. **`uses: almata-ai/veilcc-protect@v1` only resolves for everyone if the repo is public.**
   An action in a private repo can only be used inside the same org/enterprise.

It's safe: nothing in here is secret. The protection runs server-side on your API;
this action just uploads an object and reads back the result with the caller's key.

## Prerequisites

- **Two-factor auth enabled** on the publishing account/org (GitHub requires it to
  list on the Marketplace).
- `action.yml` at the repo **root** with `name`, `description`, and `branding`
  (icon + color). ✅ already set here (`VeilCC Protect`, shield/purple).
- A unique action **name** across the Marketplace. "VeilCC Protect" should be free;
  if it's taken, rename it in `action.yml`.

## 1. Create the repo and push

```sh
# from this directory (the standalone action repo)
gh repo create almata-ai/veilcc-protect --public --source=. --remote=origin --push \
  --description "Protect compiled binaries against AI reverse-engineering, in CI."
# (almata-ai is the org; swap it if you publish elsewhere)
```

If you created the repo in the browser instead:

```sh
git remote add origin git@github.com:almata-ai/veilcc-protect.git
git push -u origin main
```

## 2. Cut a release (automated)

Releases are automated by `.github/workflows/release.yml`: **push a semver tag** and it
creates the GitHub Release (auto-generated notes, marked latest) and moves the major
tag (`v1`) that consumers pin to. One command, from the CLI:

```sh
scripts/release.sh v1.0.0        # tags v1.0.0 + pushes → the workflow does the rest
# equivalently:  git tag -a v1.0.0 -m "…" && git push origin v1.0.0
```

`ci.yml` also runs on every push/PR: it lints `action.yml` (incl. the 125-char
description limit) and smoke-tests `entrypoint.sh` against a stub gateway.

> The very first push of `v1.0.0` (from step 1) triggers this and creates the initial
> release for you.

## 3. Publish to the Marketplace

1. On GitHub: the repo → **Releases** → **Draft a new release** (or edit the release
   for `v1.0.0`).
2. On the release page you'll see **"Publish this Action to the GitHub Marketplace."**
   Check it. (It only appears when `action.yml` is at the root and valid.)
3. First time only: accept the **GitHub Marketplace Developer Agreement**.
4. Pick a **Primary category** (e.g. *Security*) and optionally a secondary
   (*Continuous integration*).
5. GitHub validates the metadata (name uniqueness, branding, README). Fix anything it
   flags, then **Publish release**.

Your listing appears at `https://github.com/marketplace/actions/veilcc-protect`.

## 4. How users consume it

```yaml
- uses: almata-ai/veilcc-protect@v1
  with:
    input: license.o
    level: seal
    proto: "uint32_t check_license(const char*)"
    api-key: ${{ secrets.VEILCC_KEY }}
```

They create a key in your console (**API keys**), store it as the repo secret
`VEILCC_KEY`, and go. See `README.md` / `examples/release.yml`.

## 5. Shipping updates

- Commit changes, then `scripts/release.sh v1.1.0` — the workflow creates the release
  and moves `v1` to it. No manual tagging.
- To surface the new version on the Marketplace, open the auto-created release and tick
  **Publish to the Marketplace** (the only step the API/CLI can't do). Breaking changes
  → `scripts/release.sh v2.0.0`; the workflow creates `v2`, and `v1` stays put.

## Keeping this in sync with the monorepo

The source of truth is `action/` in the main `veilcc` repo (its CI smoke-tests
`entrypoint.sh`). This repo is the published copy. When you change the action there,
copy `action.yml`, `entrypoint.sh`, and `examples/` over here and cut a new tag — or
wire a small "sync" workflow/subtree later.
