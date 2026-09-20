.DEFAULT_GOAL := all
.PHONY: all svg png check hook clean

require = $(if $(shell command -v $1),,$(error $1 is required but not installed))

# One stamp per template, since whiskers decides which SVGs a template produces
TEMPLATES := $(wildcard templates/*.svg.tera)
STAMPS    := $(patsubst templates/%.svg.tera,output/.stamps/%,$(TEMPLATES))

# Evaluated at parse time, so `png` runs in a sub-make after the SVGs exist
SVGS := $(wildcard output/svg/*/*.svg)
PNGS := $(patsubst output/svg/%.svg,output/png/%.png,$(SVGS))

TEMPLATE_CHECKS := $(TEMPLATES:%=check/%)
PNG_CHECKS      := $(SVGS:output/svg/%.svg=check/output/png/%.png)
.PHONY: $(TEMPLATE_CHECKS) $(PNG_CHECKS)

all: svg
	@$(MAKE) --no-print-directory png

svg: $(STAMPS)

png: $(PNGS)

output/.stamps/%: templates/%.svg.tera
	$(call require,whiskers)
	whiskers $<
	mkdir -p $(@D) && touch $@

# Converts an SVG and tags the PNG with the SHA256 of its source SVG
output/png/%.png: output/svg/%.svg
	$(call require,inkscape)
	$(call require,exiftool)
	mkdir -p $(@D)
	inkscape $< --export-type=png --export-filename=$@
	exiftool -q -overwrite_original -Comment="$$(sha256sum $< | cut -d' ' -f1)" $@

# Verify that committed outputs are up to date, without modifying anything
check: $(TEMPLATE_CHECKS) $(PNG_CHECKS)

$(TEMPLATE_CHECKS): check/%: %
	$(call require,whiskers)
	whiskers $< --check

$(PNG_CHECKS): check/output/png/%.png: output/svg/%.svg
	grep -aq "$$(sha256sum $< | cut -d' ' -f1)" output/png/$*.png \
		|| { echo "output/png/$*.png is missing or out of date with $<" >&2; exit 1; }

# Install `make check` as the pre-commit hook (FORCE=1 to overwrite an existing one)
hook:
	@hook=$$(git rev-parse --git-path hooks/pre-commit); \
	if [ -e "$$hook" ] && [ -z "$(FORCE)" ]; then \
		echo "$$hook already exists; run 'make hook FORCE=1' to overwrite it" >&2; exit 1; \
	fi; \
	printf '#!/bin/sh\nexec make -C "./%s" check\n' "$$(git rev-parse --show-prefix)" > "$$hook"; \
	chmod +x "$$hook"; \
	echo "Installed $$hook"

clean:
	rm -rf output/svg output/png output/.stamps