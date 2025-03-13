action=$1
market=$2
environment=$3
service=$4

# check if the action is valid
if [[ "$action" != "init" && "$action" != "plan" && "$action" != "apply" && "$action" != "destroy" ]]; then
    echo "Invalid action: $action"
    echo "Valid actions are: init, plan, apply, destroy"
    echo "Usage: $0 <action> market=<market> environment=<dev|pre|npd|prd> service=<service|vnet|dns|log>"
    exit 1
fi

# check if the market is in the format market=<market> else exit with error message
if [[ "$market" != market=* ]]; then
    echo "Invalid market format: $market"
    echo "Usage: $0 <action> market=<market> environment=<dev|pre|npd|prd> service=<service|vnet|dns|log>"
    exit 1
else
    market=$(echo $market | cut -d'=' -f2)
fi

# check if the market is valid from grp, pt, tr, gb, de, ro, cz, ie
if [[ "$market" != "grp" && "$market" != "pt" && "$market" != "tr" && "$market" != "gb" && "$market" != "de" && "$market" != "ro" && "$market" != "cz" && "$market" != "ie" ]]; then
    echo "Invalid market: $market"
    echo "Valid markets are: grp, pt, tr, gb, de, ro, cz, ie"
    echo "Usage: $0 <action> market=<market> environment=<dev|pre|npd|prd> service=<service|vnet|dns|log>"
    exit 1
fi

# check if the environment is in the format environment=<dev|pre|npd|prd> else exit with error message
if [[ "$environment" != environment=* ]]; then
    echo "Invalid environment format: $environment"
    echo "Usage: $0 <action> market=<market> environment=<dev|pre|npd|prd> service=<service|vnet|dns|log>"
    exit 1
else
    environment=$(echo $environment | cut -d'=' -f2)
fi

# check if the environment is valid from dev, pre, npd, prd
if [[ "$environment" != "dev" && "$environment" != "pre" && "$environment" != "npd" && "$environment" != "prd" ]]; then
    echo "Invalid environment: $environment"
    echo "Valid environments are: dev, pre, npd, prd"
    exit 1
fi

# check if the service is in the format service=<service|vnet|dns|log> else exit with error message
if [[ "$service" != service=* ]]; then
    echo "Invalid service format: $service"
    echo "Usage: $0 <action> market=<market> environment=<dev|pre|npd|prd> service=<service|vnet|dns|log>"
    exit 1
else
    service=$(echo $service | cut -d'=' -f2)
fi

# check if the service is valid from dns, log, vnet, services
if [[ "$service" != "dns" && "$service" != "log" && "$service" != "vnet" && "$service" != "services" ]]; then
    echo "Invalid service: $service"
    echo "Valid services are: dns, log, vnet, services"
    exit 1
fi

env_type="npd"
if [[ "$environment" == "prd" ]]; then
    env_type="prd"
fi

echo "market is $market"
echo "environment is $environment"
echo "service is $service"
echo "env_type is $env_type"

# Get the backend variables
export PYTHONPATH=$PYTHONPATH:$(pwd)
temp_backend_output_file=$(mktemp)
python3 \
./scripts/src/backend.py \
--backend variables/grp/prd/bed.yaml \
--variables variables/$market/$environment/$service.yaml \
--output-file $temp_backend_output_file

# Read the backend output file and set the environment variables
source $temp_backend_output_file

cd terraform/$service

if [[ "$action" == "init" ]]; then
    echo "Running terraform init"

    terraform init \
    -backend-config="subscription_id=$TERRAFORM_BACKEND_AZURE_SUBSCRIPTION_ID" \
    -backend-config="resource_group_name=$TERRAFORM_BACKEND_AZURE_RESOURCE_GROUP_NAME" \
    -backend-config="storage_account_name=$TERRAFORM_BACKEND_AZURE_STORAGE_ACCOUNT_NAME" \
    -backend-config="container_name=$TERRAFORM_BACKEND_AZURE_CONTAINER_NAME" \
    -backend-config="key=$TERRAFORM_BACKEND_AZURE_KEY"
fi

if [[ "$action" == "plan" ]]; then
    echo "Running terraform plan"
    terraform plan \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type
fi

if [[ "$action" == "apply" ]]; then
    echo "Running terraform apply"
    terraform apply \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type \
    -auto-approve
fi

if [[ "$action" == "destroy" ]]; then
    echo "Running terraform destroy"
    terraform destroy \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type \
    -auto-approve
fi

