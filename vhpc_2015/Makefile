# file of the given name existing.
# .PHONY: expo_tlm_ccgrid2014 all clean

# The first rule in a Makefile is the one executed by default ("make"). It
# should always be the "all" rule, so that "make" and "make all" are identical.
all: container_hpc.pdf

# CUSTOM BUILD RULES

# In case you didn't know, '$@' is a variable holding the name of the target,
# and '$<' is a variable holding the (first) dependency of a rule.
# "raw2tex" and "dat2tex" are just placeholders for whatever custom steps
# you might have.


# MAIN LATEXMK RULE

# -pdf tells latexmk to generate PDF directly (instead of DVI).
# -pdflatex="" tells latexmk to call a specific backend with specific options.
# -use-make tells latexmk to call make for generating missing files.

# -interactive=nonstopmode keeps the pdflatex backend from stopping at a
# missing file reference and interactively asking you for an alternative.

# Generate eps filenames
EPS_FIGS=$(shell find figures | grep '\.eps')
SVG_FIGS=$(shell find figures | grep '\.svg')

PDF_FIGS=$(addsuffix .pdf,$(basename $(SVG_FIGS)))


# Generate overlay filenames
OVERLAY_SRCS=$(shell ls figures/*__ov.svg)
OVERLAYS=$(basename $(OVERLAY_SRCS))

# EPS generation rule
# figures/%.pdf : figures/%.eps
# 	ps2pdf -dEPSCrop $^ $@

# Overlay generation rule
figures/%__ov: figures/%__ov.svg
	./export_overlays $^

# # SVG generation rule
figures/%.pdf: figures/%.svg
	inkscape $^ -z -C -j -A $(basename $^).pdf

# # Proxy rule for all figures
figures:  $(PDF_FIGS) $(OVERLAYS)


container_hpc.pdf: figures container_hpc.tex
		latexmk -pdf -pdflatex="xelatex -interactive=nonstopmode -shell-escape" -use-make container_hpc.tex

clean:
	latexmk -CA
	rm *.bbl
