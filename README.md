# jessetnroberts.com

Personal and academic site for Jesse Roberts (Tennessee Tech, LAIR group). It's built with
Jekyll on a customized fork of the [AcademicPages](https://github.com/academicpages/academicpages.github.io)
theme and is deployed to GitHub Pages by GitHub Actions.

## Where things live

| What | Where |
| --- | --- |
| Homepage text | `_pages/about.md` |
| Top navigation | `_data/navigation.yml` |
| Goal trackers (homepage) | `_data/goals.yml` (rendered by `_includes/goals.html`) |
| Strava / Goodreads widgets | `_includes/widgets/` |
| Publications list | `_data/citations.csv` (plus detail pages in `_publications/`) |
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

## Deploying

Every push to `master` runs `.github/workflows/pages.yml`, which builds the site and publishes it.
In **Settings → Pages**, the source must be set to **GitHub Actions**. Pull requests get a build
check but aren't deployed.
