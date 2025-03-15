echo "Patching AzureML Private Endpoint"
file_to_patch="./terraform/services/.terraform/modules//aml.azureml/main.privateendpoint.tf"
input_file="./patch/aml/pe.patch"
if [ ! -f $file_to_patch ]; then
    echo "File $file_to_patch does not exist."
    exit 1
fi
echo "Applying patch to $file_to_patch"
echo "Apply patch from $input_file"
patch -u $file_to_patch -i $input_file
echo "Patch applied successfully"