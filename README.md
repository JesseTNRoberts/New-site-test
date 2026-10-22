# jessetnroberts.com

Personal and academic site for Jesse Roberts (Tennessee Tech, LAIR group). It's built with
Jekyll on a customized fork of the [AcademicPages](https://github.com/academicpages/academicpages.github.io)
theme and is deployed to GitHub Pages by GitHub Actions.

## Where things live

| What | Where |
| --- | --- |
| Homepage text | `_pages/about.md` |
| Top navigation | `_data/navigation.yml` |
| Goal trackers (homepage) | targets in `_data/goals.yml`; live numbers in `_data/stats.yml` (auto, daily) |
| Strava / Goodreads widgets | `_includes/widgets/` |
| Publications list | `_data/publications.yml`, mirrored from Google Scholar daily (`_data/citations.csv` is the fallback) |
| Courses | `_teaching/` |
| Interactive demos | files in `assets/demonstrations/`, listed in `_data/demos.yml` (shown on `/learn/`) |
| Torch Canvas models | `_data/torch_canvas.yml` (links `/torch-canvas/?open=<id>`; button: `{% include torch-canvas-link.html model="<id>" %}`) |
| Lecture slides | `assets/lectures/<COURSE>/` |
| CV | `_pages/cv.md` |
| Downloadable files (PDFs) | `files/` |
| Journal and meeting notes (unpublished) | `_posts/` (`published: false`) |
| Site settings, author profile, social links | `_config.yml` |

## Other sites under this domain

GitHub serves Pages from Jesse's other repos under this domain, for example
`https://www.jessetnroberts.com/torch-canvas/` and `/SP25-CSC4220/`.

- **Don't** create files, folders, permalinks or redirects in this repo with those names.
- **Don't** remove the custom domain from this repo's Pages settings, because every project site's URL depends on it.

## Local preview

```bash
bundle install
bundle exec jekyll serve --livereload   # http://localhost:4000
```

## Automatic updates (Google Scholar, Strava)

The workflow runs every day at about 5:23am Central and on every push. It runs
`scripts/update_stats.rb`, which:

- reads your Google Scholar profile (the URL in `_config.yml`), rewrites the Publications page
  list, and counts this year's papers. Scholar blocks GitHub's servers, so this goes through
  [SerpApi](https://serpapi.com) (free plan; add its key as the `SERPAPI_KEY` repo secret).
  If Scholar can't be reached, the last good numbers and list are kept (the page shows
  `_data/citations.csv` until the first successful mirror);
- reads this year's running miles from Strava's year-to-date totals. It uses only the basic
  `read` permission, never individual activities, and counts activities visible to Everyone.
  This needs the three `STRAVA_*` repo secrets; run `ruby scripts/strava_auth.rb` once to get them.

If a source fails, its last numbers are kept. You can also start it by hand under
**Actions → Build and deploy site → Run workflow**.

## Deploying

Every push to `master` runs `.github/workflows/pages.yml`, which builds the site and publishes it.
In **Settings → Pages**, the source must be set to **GitHub Actions**. Pull requests get a build
check but aren't deployed.
