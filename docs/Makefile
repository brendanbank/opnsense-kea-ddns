.PHONY: all clean html

all: keaddns.md html

keaddns.md: keaddns.rst rst2md.py
	python3 rst2md.py

html: keaddns.rst conf.py index.rst
	sphinx-build -b html . _build/html
	cp -r _build/html/_static .
	cp _build/html/index.html _build/html/keaddns.html _build/html/search.html _build/html/searchindex.js _build/html/genindex.html .

clean:
	rm -f keaddns.md
	rm -rf _build _static
	rm -f index.html keaddns.html search.html searchindex.js genindex.html
