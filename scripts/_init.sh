terraform init \
-backend-config="subscription_id=883c9081-23ed-4674-95c5-45c74834e093" \
-backend-config="resource_group_name=stcwe-rg-tfs-01" \
-backend-config="storage_account_name=stcwetfstate01" \
-backend-config="container_name=tfstate" \
-backend-config="key=pt/dev/services.tfstate"

terraform plan \
-var market=pt \
-var environment=dev

 terraform apply \
 -var market=pt \
 -var environment=dev

 terraform destroy \
 -var market=pt \
 -var environment=dev

 