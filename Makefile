default: AWS-deploy
init:
	terraform init

plan: init
	terraform plan

apply: plan
	terraform apply -auto-approve

destroy: init
	terraform destroy -auto-approve

build:
	npm install
	npm run build

deploy: build apply
	./deploy.sh

clean:
	rm -rf node_modules dist .terraform terraform.tfstate*

docker-build:
	docker build -t jewelry-app .

docker-run: docker-build
	docker run -p 8080:80 jewelry-app

azure-deploy: apply
	@echo "Aguarde alguns minutos para a aplicação inicializar..."
	@echo "URL: http://$$(terraform output -raw vm_public_ip):8080"

azure-destroy:
	terraform destroy -auto-approve
