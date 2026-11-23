# UChicago PBI Imaging Score

Bedside calculator for the UChicago PBI Imaging Score (Mansour et al., *J Neurotrauma* 2025;42:689–699, [doi:10.1089/neu.2024.0464](https://doi.org/10.1089/neu.2024.0464)).

It's a static web app: one HTML page with no build step, no backend, and no third-party scripts. It can be installed to a phone's home screen and works offline after the first visit. Nothing entered into the calculator is sent anywhere.

## Raw and rescaled scores

The score is published on a 0–100 scale, but the highest attainable raw score is 81. That's because trajectory level and ventricular blood extent are each a single choice, so their two options can't both count. The app shows the raw score as the main figure, since the bands and the cohort thresholds (25, 30, 35) are defined on it. Alongside it, the app shows a rescaled value, raw ÷ 81 × 100 rounded to a whole number, so that the highest attainable score reads as 100. The rescaled value is for readability only; the weights and score are unchanged. The axis shades 81–100 as not attainable.

The maximum is computed from the inputs (the top option of each choose-one group plus every checkbox), so it stays correct if the weights are ever edited.

## Scoring a CSV of cases

Switch to **CSV of cases** at the top of the page (or open the app URL with `#batch` at the end). Load a CSV and download the same file with four columns added: `pbi_score` (raw), `pbi_score_rescaled`, `pbi_band`, and `pbi_flag`. The file is processed in the browser and never uploaded, and this works offline too.

One row per case, with a header row. Coding is 1 = present, 0 = absent:

| Column | Feature | Points |
| --- | --- | ---: |
| `deidID` | De-identified case ID | |
| `traj_above_3v` | Transhemispheric projectile above the level of the third ventricle | 11 |
| `traj_below_3v` | Transhemispheric projectile below the level of the third ventricle | 18 |
| `ivh_partial` | Partial presence of blood in the lateral ventricles | 9 |
| `ivh_casted` | Bilateral casted lateral ventricles | 18 |
| `brainstem` | Brainstem involvement | 14 |
| `ambient_cistern_blood` | Blood in the ambient cistern | 9 |
| `cerebellar` | Cerebellar involvement | 9 |
| `ventricular_effacement` | Ventricular effacement | 4 |
| `midline_shift` | Midline shift > 0 mm | 4 |
| `perforating` | Perforating injury | 3 |
| `ich_gt_20mm` | Intracerebral hematoma > 20 mm | 2 |

As in the single-case calculator, at most one of the two `traj_` columns and at most one of the two `ivh_` columns can be 1. Column names ignore case, spaces, and underscores, and column order doesn't matter. Other columns pass through unchanged. Comma, semicolon, and tab delimiters are all detected, and the output uses the same one.

A row is left unscored, with the reason in `pbi_flag`, when a feature cell is blank, isn't 1 or 0, or breaks a choose-one rule. Blanks are never treated as 0. Rows with a blank or repeated `deidID` are still scored but flagged.

The column names and weights come from the calculator's own inputs in `site/index.html` (`data-col` and `data-w`), so the batch scores always match the single-case calculator. The format table on the page is generated from the same place.

## Design

The colors come from the UChicago palette: Phoenix Maroon (#800000) for the title, buttons, and selection marks, with Light and Dark Greystone and Footer Grey for the neutrals. The severity bands use Dark Greystone, Goldenrod, and Dark Terracotta, then a crimson for "very high", so the top band never reads as the brand maroon. A few shades are deepened beyond the brand values so small text meets WCAG contrast. In dark mode, maroon appears as a muted rose, because #800000 is unreadable on a dark background.

Type is EB Garamond, an open-source Garamond close to the Adobe Garamond Pro in UChicago's identity. It is bundled in `site/fonts/` (subset to Latin and Greek, about 93 KB per style) under the SIL Open Font License (`site/fonts/OFL.txt`). That way the page makes no requests to font services and still works offline. Monospace is kept only for CSV column names.

## Layout

```
site/                  ← everything that gets published
  index.html           the calculator (canonical source)
  manifest.webmanifest app name, icons, colors for "Install" / "Add to Home Screen"
  sw.js                service worker for offline use
  icons/               app icons and favicon
  fonts/               EB Garamond (OFL), self-hosted
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
