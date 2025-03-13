market=$1
environment=$2
service=$3

# check if the market, environment, and service are set
if [ -z "$market" ]; then
    echo "Market is not set"
    exit 1
fi
if [ -z "$environment" ]; then
    echo "Environment is not set"
    exit 1
fi
if [ -z "$service" ]; then
    echo "Service is not set"
    exit 1
fi

env_type="npd"
input_environment="${{ inputs.environment }}"
echo "Input environment is $input_environment"
if [[ "$input_environment" == "prd" ]]; then
    env_type="prd"
fi

echo "market is $market"
echo "environment is $environment"
echo "service is $service"
echo "env_type is $env_type"

echo "Running init.sh"

cd terraform/$service

terraform plan \
-var market=$market \
-var environment=$environment \
-var env_type=$env_type