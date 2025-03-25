action=$1
market=$2
environment=$3
service=$4
backend=$5

current_working_directory=$(pwd)

echo_usage() {
    echo "Usage: $0 <action> market=<market> environment=<dev|pre|npd|prd> service=<services|vnet|dns|log> backend=<true|false>"
}

change_to_current_working_directory() {
    # change to the current working directory
    cd $current_working_directory
    echo "Changed directory to $current_working_directory"
}

change_to_service_directory() {
    # change to the service directory
    cd $current_working_directory/terraform/$service
    echo "Changed directory to $current_working_directory/terraform/$service"
}

# check if the action is valid
# if [[ "$action" != "init" && "$action" != "plan" && "$action" != "apply" && "$action" != "destroy" && "$action" != "import" && "$action" != "reset" && "$action" != "release" ]]; then
actions=("init", "plan", "apply", "destroy", "import", "reset", "release", "list", "show")
if [[ ${actions[@]} =~ $action ]]; then
    echo "Valid action: $action"
else
    echo "Invalid action: $action"
    echo "Valid actions are: init, plan, apply, destroy, import, reset, release, list"
    echo_usage
    exit 1
fi

# check if the market is in the format market=<market> else exit with error message
if [[ "$market" != market=* ]]; then
    echo "Invalid market format: $market"
    echo_usage
    exit 1
else
    market=$(echo $market | cut -d'=' -f2)
fi

# check if the market is valid from grp, pt, tr, gb, de, ro, cz, ie
markets=("grp", "pt", "tr", "gb", "de", "ro", "cz", "ie")
if [[ ${markets[@]} =~ $market ]]; then
    echo "Valid market: $market"
else
    echo "Invalid market: $market"
    echo "Valid markets are: grp, pt, tr, gb, de, ro, cz, ie"
    echo_usage
    exit 1
fi

# check if the environment is in the format environment=<dev|pre|npd|prd> else exit with error message
if [[ "$environment" != environment=* ]]; then
    echo "Invalid environment format: $environment"
    echo_usage
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

# check if the service is in the format service=<services|vnet|dns|log> else exit with error message
if [[ "$service" != service=* ]]; then
    echo "Invalid service format: $service"
    echo_usage
    exit 1
else
    service=$(echo $service | cut -d'=' -f2)
fi

# check if the service is valid from dns, log, vnet, buildsvr, services
services=("services", "dns", "log", "vnet", "buildsvr", "rbac")
if [[ ${services[@]} =~ $service ]]; then
    echo "Valid service: $service"
else
    echo "Invalid service: $service"
    echo "Valid services are: dns, log, vnet, services"
    exit 1
fi

# check if the backend is in the format backend=<true|false> else exit with error message
if [[ "$backend" != backend=* ]]; then
    echo "Invalid backend format: $backend"
    echo_usage
    exit 1
else
    backend=$(echo $backend | cut -d'=' -f2)
fi

env_type="npd"
if [[ "$environment" == "prd" ]]; then
    env_type="prd"
fi

echo "market is $market"
echo "environment is $environment"
echo "service is $service"
echo "env_type is $env_type"
echo "Current working directory is $current_working_directory"

terraform fmt -recursive

source_backend() {
    backend_env_file="$current_working_directory/variables/grp/$env_type/bed.env"
    echo "Backend env file is $backend_env_file"
    source $backend_env_file
}

apply_patch() {
    if [[ "$service" == "services" ]]; then
        change_to_current_working_directory
        echo "Changeing directory to $current_working_directory"

        echo "Running patch for AML Private Endpoint"
        patch_file_path="./patch/patch.sh"
        if test -e $patch_file_path; then
            chmod +x $patch_file_path
            ./patch/patch.sh
        else
            echo "Patch file $patch_file_path not found"
            exit 1
        fi
        echo "Patch completed"
    fi
}

init_terraform() {

    change_to_current_working_directory
    source_backend

    TERRAFORM_BACKEND_AZURE_KEY=$market/$environment/$service.tfstate
    echo "TERRAFORM_BACKEND_AZURE_KEY is $TERRAFORM_BACKEND_AZURE_KEY"
    
    change_to_service_directory
    echo "Changing directory to terraform/$service"

    echo "Clearing terraform state"
    rm -rf .terraform
    rm -rf .terraform.lock.hcl
    rm -rf terraform.tfstate
    rm -rf terraform.tfstate.backup

    echo "Running terraform init"

    if [[ "$backend" == "true" ]]; then
        echo "Enabling backend"
        terraform init \
        -backend-config="subscription_id=$TERRAFORM_BACKEND_AZURE_SUBSCRIPTION_ID" \
        -backend-config="resource_group_name=$TERRAFORM_BACKEND_AZURE_RESOURCE_GROUP_NAME" \
        -backend-config="storage_account_name=$TERRAFORM_BACKEND_AZURE_STORAGE_ACCOUNT_NAME" \
        -backend-config="container_name=$TERRAFORM_BACKEND_AZURE_CONTAINER_NAME" \
        -backend-config="key=$TERRAFORM_BACKEND_AZURE_KEY"
    else
        echo "Disabling backend"
        terraform init -backend=false
    fi

    apply_patch
}


if [[ "$action" == "init" ]]; then
    init_terraform
fi

if [[ "$action" == "plan" ]]; then
    init_terraform
    change_to_current_working_directory
    change_to_service_directory
    echo "Running terraform plan"
    terraform plan \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type
    -backend
fi

if [[ "$action" == "apply" ]]; then
    init_terraform
    change_to_current_working_directory
    echo "Changing directory to $current_working_directory"
    change_to_service_directory
    echo "Changing directory to terraform/$service"
    echo "Running terraform apply"
    terraform apply \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type \
    -auto-approve
fi

if [[ "$action" == "destroy" ]]; then
    init_terraform
    change_to_current_working_directory
    change_to_service_directory
    echo "Running terraform destroy"
    terraform destroy \
    -var market=$market \
    -var environment=$environment \
    -var env_type=$env_type \
    -auto-approve
fi

if [[ "$action" == "import" ]]; then
    init_terraform
    change_to_current_working_directory
    export PYTHONPATH=$current_working_directory
    echo "Running terraform import"
    python3 \
    ./scripts/src/import/$service.py \
    --service $service \
    --market $market \
    --environment $environment \
    --env-type $env_type \
    --folder terraform/$service \
    --services-variables variables/$market/$environment/$service.yaml \
    --vnet-variables variables/$market/$env_type/vnet.yaml \
    --dns-variables variables/grp/prd/dns.yaml \
    --remote-vnet-variables variables/grp/$env_type/vnet.yaml \
    --firewall-variables variables/grp/$env_type/firewall.yaml \
    --log-variables variables/grp/$env_type/log.yaml \
    --yes
fi

if [[ "$action" == "reset" ]]; then
    change_to_current_working_directory
    echo "Running terraform reset"
    
    source_backend
    
    TERRAFORM_BACKEND_AZURE_KEY=$market/$environment/$service.tfstate
    echo "TERRAFORM_BACKEND_AZURE_KEY is $TERRAFORM_BACKEND_AZURE_KEY"
    
    az storage blob delete \
    --subscription $TERRAFORM_BACKEND_AZURE_SUBSCRIPTION_ID \
    --account-name $TERRAFORM_BACKEND_AZURE_STORAGE_ACCOUNT_NAME \
    --container-name $TERRAFORM_BACKEND_AZURE_CONTAINER_NAME \
    --name $TERRAFORM_BACKEND_AZURE_KEY \
    --auth-mode login
fi

if [[ "$action" == "release" ]]; then
    change_to_current_working_directory
    echo "Running storage blob release"
    
    source_backend

    TERRAFORM_BACKEND_AZURE_KEY=$market/$environment/$service.tfstate
    echo "TERRAFORM_BACKEND_AZURE_KEY is $TERRAFORM_BACKEND_AZURE_KEY"
    
    az storage blob lease break \
    --subscription $TERRAFORM_BACKEND_AZURE_SUBSCRIPTION_ID \
    --account-name $TERRAFORM_BACKEND_AZURE_STORAGE_ACCOUNT_NAME \
    --container-name $TERRAFORM_BACKEND_AZURE_CONTAINER_NAME \
    --auth-mode login \
    --blob-name $TERRAFORM_BACKEND_AZURE_KEY
fi

if [[ "$action" == "list" ]]; then
    init_terraform
    change_to_current_working_directory
    change_to_service_directory
    echo "Running terraform destroy"
    terraform state list
fi

if [[ "$action" == "show" ]]; then
    init_terraform
    change_to_current_working_directory
    change_to_service_directory
    echo "Running terraform destroy"
    terraform show
fi
