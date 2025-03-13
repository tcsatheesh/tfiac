market=$1
environment=$2
az_svc=$3

# check if the market, environment, and az_svc are set
if [ -z "$market" ]; then
    echo "Market is not set"
    exit 1
fi
if [ -z "$environment" ]; then
    echo "Environment is not set"
    exit 1
fi
if [ -z "$az_svc" ]; then
    echo "Az Svc is not set"
    exit 1
fi

echo "Market is $market"
echo "Environment is $environment"
echo "Az Svc is $az_svc"
echo "Running init.sh"


export PYTHONPATH=$PYTHONPATH:$(pwd)
temp_backend_output_file=$(mktemp)
python3 \
./scripts/src/backend.py \
--backend variables/grp/prd/bed.yaml \
--variables variables/$market/$environment/$az_svc.yaml \
--output-file $temp_backend_output_file

# Read the backend output file and set the environment variables
source $temp_backend_output_file

cd terraform/$az_svc

terraform init \
    -backend-config="subscription_id=$TERRAFORM_BACKEND_AZURE_SUBSCRIPTION_ID" \
    -backend-config="resource_group_name=$TERRAFORM_BACKEND_AZURE_RESOURCE_GROUP_NAME" \
    -backend-config="storage_account_name=$TERRAFORM_BACKEND_AZURE_STORAGE_ACCOUNT_NAME" \
    -backend-config="container_name=$TERRAFORM_BACKEND_AZURE_CONTAINER_NAME" \
    -backend-config="key=$TERRAFORM_BACKEND_AZURE_KEY"