OBO=http://purl.obolibrary.org/obo
ONT=to
BASE=$(OBO)/$(ONT)
#SRC=plant-trait-ontology.obo.owl
SRC=plant-trait-ontology.obo
RELEASEDIR=.
ROBOT= robot
OWLTOOLS= owltools


all: all_imports $(ONT).owl $(ONT).obo subsets/$(ONT)-basic.obo
test: $(ONT).owl $(ONT).obo
prepare_release: all

$(ONT).owl: $(SRC)
	$(ROBOT)  reason -i $< -r ELK relax reduce -r ELK annotate -V $(BASE)/releases/`date +%Y-%m-%d`/$(ONT).owl -o $@
$(ONT).obo: $(ONT).owl
	$(ROBOT) convert -i $< -f obo -o $(ONT).obo.tmp && grep -v '^owl-axioms:' $(ONT).obo.tmp > $@ && rm $(ONT).obo.tmp

subsets/$(ONT)-basic.obo: $(ONT).owl
	owltools --use-catalog $< --remove-imports-declarations --make-subset-by-properties -f BFO:0000050 --remove-dangling --remove-axioms -t EquivalentClasses --set-ontology-id $(OBO)/subsets/$(ONT)-basic.owl -o -f obo $@.tmp && mv $@.tmp $@

IMPORTS = chebi pato eo po go
IMPORTS_OWL = $(patsubst %, imports/%_import.owl,$(IMPORTS)) $(patsubst %, imports/%_import.obo,$(IMPORTS))

# Make this target to regenerate ALL
all_imports: $(IMPORTS_OWL)

# Use ROBOT, driven entirely by terms lists NOT from source ontology
imports/%_import.owl: mirror/%.owl imports/%_terms.txt
	$(ROBOT) extract -i $< -T imports/$*_terms.txt --method BOT -O  $(BASE)/$@ -o $@
.PRECIOUS: imports/%_import.owl

imports/%_import.obo: imports/%_import.owl
	$(OWLTOOLS) $(USECAT) $< -o -f obo $@

# clone remote ontology locally, perfoming some excision of relations and annotations
mirror/%.obo: $(SRC) 
	test -d mirror || mkdir mirror &&\
	wget --no-check-certificate $(OBO)/$*.obo -O $@ && touch $@
.PRECIOUS: mirror/%.obo
mirror/%.owl: mirror/%.obo
	$(OWLTOOLS) --no-debug $< --remove-annotation-assertions -l -s -d --remove-dangling-annotations --set-ontology-id $(OBO)/$*.owl  -o $@
.PRECIOUS: mirror/%.owl

release: $(ONT).owl $(ONT).obo


#######PATTERNS
PATTERNS_EQ_OWL = $(patsubst %.tsv, %_pattern.owl, $(wildcard patterns/eq/*.tsv)) $(patsubst %.tsv, %_pattern.obo, $(wildcard patterns/eq/*.tsv))
PATTERNS_MORPH_OWL = $(patsubst %.tsv, %_pattern.owl, $(wildcard patterns/morphology/*.tsv)) $(patsubst %.tsv, %_pattern.obo, $(wildcard patterns/morphology/*.tsv))
PATTERNS_RESPONSE_OWL = $(patsubst %.tsv, %_pattern.owl, $(wildcard patterns/response/*.tsv)) $(patsubst %.tsv, %_pattern.obo, $(wildcard patterns/response/*.tsv))
PATTERNS_COMPOSITION_OWL = $(patsubst %.tsv, %_pattern.owl, $(wildcard patterns/composition/*.tsv)) $(patsubst %.tsv, %_pattern.obo, $(wildcard patterns/composition/*.tsv))
PATTERNS_COLOR_OWL = $(patsubst %.tsv, %_pattern.owl, $(wildcard patterns/color/*.tsv)) $(patsubst %.tsv, %_pattern.obo, $(wildcard patterns/color/*.tsv))


all_patterns: $(PATTERNS_COLOR_OWL)
	#$(PATTERNS_COMPOSITION_OWL) $(PATTERNS_MORPH_OWL) $(PATTERNS_EQ_OWL) $(PATTERNS_RESPONSE_OWL)

patterns/eq/%_pattern.owl: patterns/eq/%.tsv
	patterns/apply-pattern.py -P patterns/curie_map.yaml -i patterns/eq/$*.tsv -p patterns/eq.yaml -n $@ > $@

patterns/eq/%_pattern.obo: patterns/eq/%_pattern.owl
	$(OWLTOOLS) $< -o -f obo $@

patterns/morphology/%_pattern.owl: patterns/morphology/%.tsv
	patterns/apply-pattern.py -P patterns/curie_map.yaml -i patterns/morphology/$*.tsv -p patterns/morphology.yaml -n $@ > $@

patterns/morphology/%_pattern.obo: patterns/morphology/%_pattern.owl
	$(OWLTOOLS) $< -o -f obo $@

patterns/response/%_pattern.owl: patterns/response/%.tsv
	patterns/apply-pattern.py -P patterns/curie_map.yaml -i patterns/response/$*.tsv -p patterns/response.yaml -n $@ > $@

patterns/response/%_pattern.obo: patterns/response/%_pattern.owl
	$(OWLTOOLS) $< -o -f obo $@

patterns/composition/%_pattern.owl: patterns/composition/%.tsv
	patterns/apply-pattern.py -P patterns/curie_map.yaml -i patterns/composition/$*.tsv -p patterns/composition.yaml -n $@ > $@

patterns/composition/%_pattern.obo: patterns/composition/%_pattern.owl
	$(OWLTOOLS) $< -o -f obo $@

patterns/color/%_pattern.owl: patterns/color/%.tsv
	patterns/apply-pattern.py -P patterns/curie_map.yaml -i patterns/color/$*.tsv -p patterns/color.yaml -n $@ > $@

patterns/color/%_pattern.obo: patterns/color/%_pattern.owl
	$(OWLTOOLS) $< -o -f obo $@


#merge pattern files
PATTERNS = $(patsubst %.tsv, --input %_pattern.owl, $(wildcard patterns/eq/*.tsv)) 
PATTERNS += $(patsubst %.tsv, --input %_pattern.owl, $(wildcard patterns/morphology/*.tsv)) 
PATTERNS += $(patsubst %.tsv, --input %_pattern.owl, $(wildcard patterns/response/*.tsv)) 
PATTERNS += $(patsubst %.tsv, --input %_pattern.owl, $(wildcard patterns/composition/*.tsv)) 
PATTERNS += $(patsubst %.tsv, --input %_pattern.owl, $(wildcard patterns/color/*.tsv)) 

merge:
	$(ROBOT) merge $(PATTERNS) --output patterns/merge_patterns.owl
	$(OWLTOOLS) patterns/merge_patterns.owl -o -f obo patterns/merge_patterns.obo

#print var function
print-%:
	@echo $* = $($*)