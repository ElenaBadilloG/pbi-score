# UChicago PBI Imaging Score

Bedside calculator for the UChicago PBI Imaging Score (Mansour et al., *J Neurotrauma* 2025;42:689–699, [doi:10.1089/neu.2024.0464](https://doi.org/10.1089/neu.2024.0464)).

It's a static web app: one HTML page with no build step, no backend, and no third-party scripts. It can be installed to a phone's home screen and works offline after the first visit. Nothing entered into the calculator is sent anywhere.

## Layout

```
site/                  ← everything that gets published
  index.html           the calculator (canonical source)
  manifest.webmanifest app name, icons, colors for "Install" / "Add to Home Screen"
  sw.js                service worker for offline use
  icons/               app icons and favicon
serve.py               local preview server
build_artifact.py      derives artifact.html (Claude Artifact version) from site/index.html
tools/make_icons.py    regenerates the icons (only needed if you redesign them)
reference/             the source article (git-ignored, not published)
.github/workflows/     automatic deploy to GitHub Pages
```

## Run it locally

```
python3 serve.py
```

Then open http://127.0.0.1:8777. Use `PORT=9000 python3 serve.py` to change the port. Opening `site/index.html` directly as a file also works; you just won't get offline/install support that way.

## Publish it

### GitHub Pages (recommended, free)

The quick way, from this folder in Terminal:

```
bash publish.sh            # creates github.com/<you>/pbi-score
bash publish.sh my-name    # or choose the repo name
```

It signs you in to GitHub if needed, creates the repo, pushes, sets Pages to deploy from GitHub Actions, waits for the deploy, and prints the live URL. Run it again any time to publish changes. It needs the GitHub CLI (`brew install gh` on a Mac).

To do the same by hand:

1. Create a GitHub repository and push this folder to its `main` branch.
2. In the repository, go to **Settings → Pages** and set **Source** to **GitHub Actions**.
3. The workflow in `.github/workflows/pages.yml` runs on every push to `main`. After the first run (about a minute), the app is live at `https://<your-username>.github.io/<repo-name>/`. The link also appears on the workflow run's summary page.

To use your own domain (for example `pbi.yourlab.org`), add it under **Settings → Pages → Custom domain** and follow GitHub's DNS instructions.

If the repository is public, the source code is public too. The article PDF is excluded by `.gitignore` because it is publisher-copyrighted.

### No-account alternative: Netlify Drop

Go to https://app.netlify.com/drop and drag the `site` folder onto the page. You get a live HTTPS URL immediately. Creating a free account keeps the site from expiring and lets you redeploy by dragging the folder again.

Any static host works the same way (Cloudflare Pages, Vercel, a university web server): publish the contents of `site/` over HTTPS. HTTPS is required for offline support and installation.

## Install on a phone

On iPhone/iPad, open the URL in Safari, tap **Share**, then **Add to Home Screen**. On Android, open it in Chrome, open the **⋮** menu, then **Install app** (or **Add to Home screen**). On desktop Chrome or Edge, use the install icon in the address bar.

The installed app opens full-screen as "PBI Score" and works without a connection once it has been opened online at least once.

## Updating

Edit `site/index.html`, then push (or re-drag the folder for Netlify). Users get the new version the next time they open the app with a connection; offline users keep the last version they loaded.

If you change the icons or the manifest, also bump `CACHE` in `site/sw.js` (for example `pbi-score-v1` → `pbi-score-v2`) so installed copies refresh them.

After editing the page, run `python3 build_artifact.py` if you also maintain the Claude Artifact version.

## Privacy

The app has no analytics, cookies, or network requests beyond loading its own files, which is what keeps the on-page statement "No patient data entered here leaves this page" true. Keep it that way if you add anything (fonts, analytics, CDNs).
