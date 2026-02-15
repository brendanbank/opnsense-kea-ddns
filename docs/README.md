# Documentation

The source of truth is `keaddns.rst` (ReStructuredText). The following are auto-generated
and should not be edited directly:

- `keaddns.md` — Markdown, generated via Pandoc + `rst2md.py` post-processing
- `_build/html/` — HTML site, generated via Sphinx with the Read the Docs theme

## Building

```
make -C docs
```

This generates both the Markdown and HTML outputs.

Individual targets:

```
make -C docs keaddns.md   # Markdown only
make -C docs html         # HTML only
make -C docs clean        # Remove generated files
```

## Requirements

- Python 3
- [Pandoc](https://pandoc.org/) — `brew install pandoc`
- [Sphinx](https://www.sphinx-doc.org/) with extensions:

  ```
  pipx install sphinx
  pipx inject sphinx sphinx-rtd-theme sphinx-tabs
  ```
