SHELL=/bin/bash

all: container-lambda-fleet-registry-create fleet-template-create
.PHONY: all

AWS_PROFILE_NAME = groot
FLEET_STACK_NAME = microservice-fleet
REGISTRY_STACK_NAME = container-lambda-fleet

#######################################
############# General Rule ############
#######################################

create-everything: container-lambda-fleet-registry-create fleet-template-create

delete-everything: fleet-images-delete fleet-template-delete container-lambda-fleet-registry-delete

#######################################
###### Registry stack deployment ######
#######################################

container-lambda-fleet-registry-create:
	AWS_PROFILE=$(AWS_PROFILE_NAME) aws cloudformation create-stack --stack-name $(REGISTRY_STACK_NAME) --template-body file://repositories.yaml --capabilities CAPABILITY_AUTO_EXPAND

container-lambda-fleet-registry-update:
	AWS_PROFILE=$(AWS_PROFILE_NAME) aws cloudformation update-stack --stack-name $(REGISTRY_STACK_NAME) --template-body file://repositories.yaml --capabilities CAPABILITY_AUTO_EXPAND

container-lambda-fleet-registry-delete:
	AWS_PROFILE=$(AWS_PROFILE_NAME) aws cloudformation delete-stack --stack-name $(REGISTRY_STACK_NAME)

#######################################
##### Microservices docker builds #####
#######################################

a-microservice-sample-image-build:
# rules to replicate to build each microservice of the fleet
	cd ./fleet/a_microservice_sample && docker build -t a-microservice-sample . && docker tag a-microservice-sample:latest $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[1].OutputValue')
# samples
# the following are sample for other microservices (outputs in order from the registry stack template, consider the index of Outputs, order matters...)
# cd fleet/another_microservice_sample && docker build -t another-microservice-sample . && docker tag a-microservice-sample:latest $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[2].OutputValue')
# cd fleet/ultimate_microservice_sample && docker build -t ultimate-microservice-sample . && docker tag a-microservice-sample:latest $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[3].OutputValue')
# ...

#######################################
### Microservices stack deployments ###
#######################################

fleet-template-package:
	AWS_PROFILE=$(AWS_PROFILE_NAME) sam package --template-file fleet.yaml --image-repository $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[1].OutputValue') --output-template-file fleet-packaged.yaml

fleet-image-push:
# log into ECR registry
	AWS_PROFILE=$(AWS_PROFILE_NAME) aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[0].OutputValue')
# rules to replicate to push all microservices in the fleet (incremental id)
	docker push $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[1].OutputValue')
# samples
# the following are sample for other microservices (outputs in order from the registry stack template, consider the index of Outputs, order matters...)
# docker push $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[2].OutputValue')
# docker push $(shell aws cloudformation describe-stacks --stack-name $(REGISTRY_STACK_NAME) | jq '.Stacks[0].Outputs[3].OutputValue')
# ...

fleet-template-deploy:
	AWS_PROFILE=$(AWS_PROFILE_NAME) sam deploy --template-file ./fleet-packaged.yaml --stack-name $(FLEET_STACK_NAME) --parameter-overrides ParameterKey=ECRStackName,ParameterValue=$(REGISTRY_STACK_NAME) --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND && rm -rf fleet-packaged.yaml

# replicate the first rule build all microservices in the fleet
fleet-template-create: a-microservice-sample-image-build fleet-image-push fleet-template-package fleet-template-deploy

fleet-images-delete:
# rules to replicate to delete each microservice repository of the fleet
	AWS_PROFILE=$(AWS_PROFILE_NAME) aws ecr delete-repository --repository-name a-microservice-sample --force
# samples
# aws ecr delete-repository --repository-name another-microservice-sample | jq '.Stacks[0].Outputs[2].OutputValue') --force
# aws ecr delete-repository --repository-name ultimate-microservice-sample | jq '.Stacks[0].Outputs[3].OutputValue') --force
# ...

fleet-template-delete:
	AWS_PROFILE=$(AWS_PROFILE_NAME) aws cloudformation delete-stack --stack-name $(FLEET_STACK_NAME)