action=$1
market=$2
environment=$3
service=$4

# check if the action is valid
if [[ "$action" != "init" && "$action" != "plan" && "$action" != "apply" && "$action" != "destroy" && "$action" != "import" && "$action" != "reset" ]]; then
    echo "Invalid action: $action"
    echo "Valid actions are: init, plan, apply, destroy, import, reset"
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

terraform fmt -recursive

current_working_directory=$(pwd)
echo "Current working directory is $current_working_directory"

init_terraform() {

    cd $current_working_directory

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

    echo "Clearing terraform state"
    rm -rf .terraform
    rm -rf .terraform.lock.hcl
    rm -rf terraform.tfstate
    rm -rf terraform.tfstate.backup

    echo "Running terraform init"

    terraform init \
    -backend-config="subscription_id=$TERRAFORM_BACKEND_AZURE_SUBSCRIPTION_ID" \
    -backend-config="resource_group_name=$TERRAFORM_BACKEND_AZURE_RESOURCE_GROUP_NAME" \
    -backend-config="storage_account_name=$TERRAFORM_BACKEND_AZURE_STORAGE_ACCOUNT_NAME" \
    -backend-config="container_name=$TERRAFORM_BACKEND_AZURE_CONTAINER_NAME" \
    -backend-config="key=$TERRAFORM_BACKEND_AZURE_KEY"
}

apply_patch() {
    if [[ "$service" == "services" ]]; then
        cd $current_working_directory
        echo "Running patch for AML Private Endpoint"
        chmod +x ./patch/patch.sh
        ./patch/aml/patch.sh
        echo "Patch completed"
    fi
}

if [[ "$action" == "init" ]]; then
    init_terraform
fi

if [[ "$action" == "plan" ]]; then
    init_terraform
    cd $current_working_directory
    cd terraform/$service
    echo "Running terraform plan"
    terraform plan \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type
fi

if [[ "$action" == "apply" ]]; then
    init_terraform
    apply_patch
    cd $current_working_directory
    cd terraform/$service
    echo "Running terraform apply"
    terraform apply \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type \
    -auto-approve
fi

if [[ "$action" == "destroy" ]]; then
    init_terraform
    cd $current_working_directory
    cd terraform/$service
    echo "Running terraform destroy"
    terraform destroy \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type \
    -auto-approve
fi

if [[ "$action" == "import" ]]; then
    init_terraform
    apply_patch
    cd $current_working_directory
    echo "Running terraform import"
    python3 \
    ./scripts/src/import/$service.py \
    --market $market \
    --environment $environment \
    --env-type $env_type \
    --folder terraform/$service \
    --variables variables/$market/$environment/$service.yaml \
    --dns-variables variables/grp/prd/dns.yaml \
    --remote-vnet-variables variables/grp/$env_type/vnet.yaml \
    --firewall-variables variables/grp/$env_type/firewall.yaml \
    --yes
fi

if [[ "$action" == "reset" ]]; then
    export PYTHONPATH=$PYTHONPATH:$(pwd)
    cd $current_working_directory
    echo "Running terraform reset"
    python3 \
    ./scripts/src/__init__.py \
    reset \
    --folder terraform/$service \
    --variables variables/$market/$environment/$service.yaml \
    --yes
fi