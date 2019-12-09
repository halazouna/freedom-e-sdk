
pip-cache: requirements.txt
	python3 -m venv venv
	. venv/bin/activate && pip install --upgrade pip
	. venv/bin/activate && pip install pip-download
	mkdir -p $@
	. venv/bin/activate && pip-download -i https://pypi.org/simple -d $@ -r $<
	rm -rf venv/

venv/bin/activate: requirements.txt pip-cache
	python3 -m venv venv
	. $@ && pip install --no-index --find-links pip-cache --upgrade pip
	. $@ && pip install --no-index --find-links pip-cache -r $<

.PHONY: clean-virtualenv
clean-virtualenv:
	-rm -rf venv

