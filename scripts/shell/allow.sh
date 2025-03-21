current_working_directory=$(pwd)
echo "Current working directory is $current_working_directory"

cd $current_working_directory
backend_env_file="$current_working_directory/variables/grp/prd/bed.env"
echo "Backend env file is $backend_env_file"

# Read the backend output file and set the environment variables
source $backend_env_file

az storage account update \
--subscription $TERRAFORM_BACKEND_AZURE_SUBSCRIPTION_ID \
--resource-group $TERRAFORM_BACKEND_AZURE_RESOURCE_GROUP_NAME \
--name $TERRAFORM_BACKEND_AZURE_STORAGE_ACCOUNT_NAME \
--public-network-access Enabled
