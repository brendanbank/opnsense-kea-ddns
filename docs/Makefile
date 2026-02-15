.PHONY: all clean html

all: keaddns.md html

keaddns.md: keaddns.rst rst2md.py
	python3 rst2md.py

html: keaddns.rst conf.py index.rst
	sphinx-build -b html . _build/html

clean:
	rm -f keaddns.md
	rm -rf _build
