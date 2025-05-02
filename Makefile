DB_HOST ?= localhost
DB_NAME ?= test
DB_USER ?= user
DB_PASSWORD ?= pass

docker-build:
	docker build -t gogs .

generate-tfvars:
	@echo 'ec2_ami = "$(EC2_AMI)"' > terraform/prod/ec2/terraform.tfvars
	@echo 'ec2_key_name = "$(EC2_KEY_NAME)"' >> terraform/prod/ec2/terraform.tfvars
	@echo 'control_ip = "$(CONTROL_IP)"' >> terraform/prod/ec2/terraform.tfvars
	@echo 'agent_ip = "$(AGENT_IP)"' >> terraform/prod/ec2/terraform.tfvars

	@echo 'db_user = "$(DB_USER)"' > terraform/prod/rds/terraform.tfvars
	@echo 'db_password = "$(DB_PASSWORD)"' >> terraform/prod/rds/terraform.tfvars
	@echo 'db_name = "$(DB_NAME)"' >> terraform/prod/rds/terraform.tfvars

infra-aws:
	cd terraform/prod/network && terraform init && terraform apply -auto-approve
	cd terraform/prod/ec2 && terraform init && terraform apply -auto-approve
	cd terraform/prod/rds && terraform init && terraform apply -auto-approve
	cd terraform/prod/security-rules && terraform init && terraform apply -auto-approve

	cd terraform/prod/ec2 && terraform output -raw ec2_public_ip > ../../../EC2_IP.txt
	cd terraform/prod/rds && terraform output -raw rds_endpoint > ../../../RDS_ENDPOINT.txt

generate-app-config:
	$(eval EC2_IP=$(shell cat EC2_IP.txt))
	$(eval RDS_HOST=$(shell cat RDS_ENDPOINT.txt))

	@echo 'RUN_MODE = prod' > app.ini
	@echo '' >> app.ini
	@echo '[server]' >> app.ini
	@echo "EXTERNAL_URL = http://${EC2_IP}:3000" >> app.ini
	@echo "DOMAIN = ${EC2_IP}" >> app.ini
	@echo '' >> app.ini
	@echo '[database]' >> app.ini
	@echo "HOST = ${RDS_HOST}" >> app.ini
	@echo "USER = ${DB_USER}" >> app.ini
	@echo "PASSWORD = \\\`${DB_PASSWORD}\\\`" >> app.ini
	@echo 'SSL_MODE = require' >> app.ini
	@echo '' >> app.ini
	@echo '[security]' >> app.ini
	@echo 'INSTALL_LOCK = true' >> app.ini

save-docker-image:
	@mkdir -p docker-image
	docker save -o docker-image/gogs.tar gogs

configure:
	$(eval EC2_IP=$(shell cat EC2_IP.txt))

	ansible-galaxy collection install signalfx.splunk_otel_collector
	
	cd ansible && ANSIBLE_HOST_KEY_CHECKING=False \
	ansible-playbook -i "$(EC2_IP)," playbook.yml -u ubuntu \
	--extra-vars "ec2_ip=$(EC2_IP)" \
	--private-key $(KEY)

clean:
	docker system prune -af --volumes

	rm -rf $(WORKSPACE)/*

	sudo rm -rf /tmp/*