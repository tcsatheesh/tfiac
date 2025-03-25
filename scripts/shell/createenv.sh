market=$1
environment=$2
subscription=$3
client=$4
apply=$5

echo_usage() {
    echo "Usage: $0 market=<market> environment=<dev|pre|npd|prd> subscription=<subscription id> client=<client_name> apply=<true|false>"
}

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
environments=("dev", "pre", "npd", "prd")
if [[ ${environments[@]} =~ $environment ]]; then
    echo "Valid environment: $environment"
else
    echo "Invalid environment: $environment"
    echo "Valid environments are: dev, pre, npd, prd"
    echo_usage
    exit 1
fi

if [[ "$subscription" != subscription=* ]]; then
    echo "Invalid subscription format: $subscription"
    echo_usage
    exit 1
else
    subscription=$(echo $subscription | cut -d'=' -f2)
fi

if [[ "$client" != client=* ]]; then
    echo "Invalid client format: $client"
    echo_usage
    exit 1
else
    client_name=$(echo $client | cut -d'=' -f2)
fi


if [[ "$apply" != apply=* ]]; then
    echo "Invalid apply format: $apply"
    echo_usage
    exit 1
else
    apply=$(echo $apply | cut -d'=' -f2)
fi
if [[ "$apply" != "true" && "$apply" != "false" ]]; then
    echo "Invalid apply: $apply"
    echo "Valid apply values are: true, false"
    exit 1
fi

source .env

echo -e "\nGitHub Organization: $GITHUB_ORGANIZATION"
echo "GitHub Repository: $GITHUB_REPOSITORY"

environment_name="$market-$environment"
echo -e "\nEnvironment name: $environment_name"


env_type="nonprod"
if [[ "$environment" == "prd" ]]; then
    env_type="prod"
fi

AZURE_CLIENT_NAME=$client_name
echo -e "\nAzure Client Name: $AZURE_CLIENT_NAME"

AZURE_CLIENT_ID=$(az ad app list --display-name $AZURE_CLIENT_NAME | grep appId | awk -F ': ' '{print $2}' | tr -d '",')
AZURE_TENANT_ID=$(az account show --query tenantId --output tsv)
AZURE_SUBSCRIPTION_ID=$subscription

echo -e "\nAzure Client ID: $AZURE_CLIENT_ID"
echo -e "Azure Subscription ID: $AZURE_SUBSCRIPTION_ID"
echo -e "Azure Tenant ID: $AZURE_TENANT_ID"


environment_variables="./variables/$market/$environment/.env"
if [ -f "$environment_variables" ]; then
    echo -e "\nEnvironment variables file exists: $environment_variables. Overriding..."
    rm -rf $environment_variables
else
    echo -e "\nEnvironment variables file does not exist: $environment_variables. Creating..."   
fi

echo "AZURE_CLIENT_ID=$AZURE_CLIENT_ID" >> $environment_variables
echo "AZURE_TENANT_ID=$AZURE_TENANT_ID" >> $environment_variables
echo "AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID" >> $environment_variables

echo -e "\nEnvironment variables file created: $environment_variables"
echo -e "\nEnvironment variables:"
cat $environment_variables

if [[ "$apply" == "true" ]]; then
    echo -e "\nApplying changes..."
    # https://docs.github.com/en/rest/deployments/environments?apiVersion=2022-11-28
    gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY/environments/$environment_name
    #    -F "wait_timer=30" \
    #    -F "prevent_self_review=false" \
    #    -f "reviewers[][type]=User" \
    #    -F "reviewers[][id]=1" \
    #    -f "reviewers[][type]=Team" \
    #    -F "reviewers[][id]=1" \
    #    -F "deployment_branch_policy[protected_branches]=false" \
    #    -F "deployment_branch_policy[custom_branch_policies]=true"

    echo -e "\nEnvironment $environment_name created successfully."

    echo -e "\nSetting environment variables for $environment_name..."
    gh secret set --env-file $environment_variables --env $environment_name
    echo -e "\nEnvironment variables set successfully for $environment_name."

else
    echo -e "\nNot applying changes..."
fi



