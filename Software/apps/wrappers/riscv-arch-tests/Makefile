PYTHON     ?= python3
TEST       ?= I-add-00
EXTENSIONS ?= I,M,Zicsr,Zifencei
JOBS       ?= 0

.DEFAULT_GOAL := run

run:
	$(PYTHON) build_arch_tests.py --test $(TEST) --extensions $(EXTENSIONS) --jobs $(JOBS)

all-hex:
	$(PYTHON) build_arch_tests.py --all --extensions $(EXTENSIONS) --jobs $(JOBS)

clean:
	$(PYTHON) build_arch_tests.py --clean

.PHONY: run all-hex clean
