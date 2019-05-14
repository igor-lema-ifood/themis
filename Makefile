dir = $(shell pwd)
VENV_DIR = .venv
IMAGE_NAME = themis
VENV_RUN = . $(VENV_DIR)/bin/activate && export PYTHONPATH=.venv/lib64/python2.7/dist-packages
AWS_PROFILE = faster

usage:             ## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

build:             ## Install local pip and npm dependencies
	(test `which virtualenv` || pip install virtualenv || sudo pip install virtualenv)
	(test -e $(VENV_DIR) || (virtualenv $(VENV_DIR) && $(VENV_RUN) && pip install --upgrade pip))
	# due to a bug in scipy, numpy needs to be installed first:
	($(VENV_RUN) && pip install numpy)
	($(VENV_RUN) && pip install -r requirements.txt)
	make npm

install-prereq:    ## Install prerequisites via apt-get or yum (if available)
	which apt-get && sudo apt-get -y install libblas-dev liblapack-dev
	which yum && sudo yum -y install blas-devel lapack-devel numpy-f2py

npm:               ## Install node.js/npm dependencies
	cd $(dir)/themis/web/ && npm install

docker-build:      ## Build the Docker image
	@docker build -t $(IMAGE_NAME) .

docker-run:        ## Run Themis in local Docker container
	@docker run -it -p 8080:8080 \
	-e THEMIS_DB_PASSWORD=$(THEMIS_DB_PASSWORD) \
	-v ~/.aws/credentials:/root/.aws/credentials \
	-e AWS_PROFILE=$(AWS_PROFILE) \
	$(IMAGE_NAME) 

docker-login:
	$(aws ecr get-login --no-include-email --region us-east-1 --profile faster)

docker-tag:
	docker tag themis:latest 087833863386.dkr.ecr.us-east-1.amazonaws.com/themis:latest

docker-push:
	docker push 087833863386.dkr.ecr.us-east-1.amazonaws.com/themis:latest
	
release: docker-login docker-tag docker-push

docker: docker-build docker-run

test:              ## Run tests
	($(VENV_RUN) && PYTHONPATH=$(dir)/test:$$PYTHONPATH nosetests --nocapture --no-skip --with-coverage --with-xunit --cover-package=themis test/) && \
	make lint

lint:              ## Run code linter to check code style
	($(VENV_RUN); pep8 --max-line-length=120 --ignore=E128 --exclude=web,bin,$(VENV_DIR) .)

server:            ## Start the server on port 8081
	($(VENV_RUN) && eval `ssh-agent -s` && PYTHONPATH=$(dir)/src:$$PYTHONPATH bin/themis server_and_loop --port=8081 --log=themis.log)

.PHONY: build test
