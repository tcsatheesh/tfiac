from scripts.src.base import ImportStateBase


class ImportState(ImportStateBase):
    def __init__(
        self,
        *args,
        **kwargs,
    ):
        super().__init__(
            *args,
            **kwargs,
        )

    def _import_storage(
            self,
            storage_subscription_id,
            storage_resource_group_name,
            storage_account_name,
            vnet_subscription_id,
            vnet_resource_group_name,
            module_name,
    ):
        _logger = self._logger
        _services_subscription_id = storage_subscription_id
        _services_resource_group_name = storage_resource_group_name
        _storage_account_name = storage_account_name
        _module_name = module_name

        _vnet_subscription_id = vnet_subscription_id
        _vnet_resource_group_name = vnet_resource_group_name

        _logger.info(f"Importing Azure Storage Account {_storage_account_name}")
        self._import_resource(
            name=f"{_module_name}.azurerm_storage_account.this",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.Storage",
            resource=f"storageAccounts/{_storage_account_name}",
        )
        _logger.info(f"Importing Azure Storage Account {_storage_account_name} diagnostics for file")
        self._import_resource(
            name=f'{_module_name}.azurerm_monitor_diagnostic_setting.azure_file["file1"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.Storage",
            resource=f"storageAccounts/{_storage_account_name}/fileServices/default/|diag",
        )
        _logger.info(f"Importing Azure Storage Account {_storage_account_name} diagnostics for blob")
        self._import_resource(
            name=f'{_module_name}.azurerm_monitor_diagnostic_setting.blob["blob11"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.Storage",
            resource=f"storageAccounts/{_storage_account_name}/blobServices/default/|diag"
        )
        _logger.info(f"Importing Azure Storage Account {_storage_account_name} diagnostics for queue")
        self._import_resource(
            name=f'{_module_name}.azurerm_monitor_diagnostic_setting.queue["queue"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.Storage",
            resource=f"storageAccounts/{_storage_account_name}/queueServices/default/|diag"
        )
        _logger.info(f"Importing Azure Storage Account {_storage_account_name} diagnostics for storage")
        self._import_resource(
            name=f'{_module_name}.azurerm_monitor_diagnostic_setting.storage_account["storage"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.Storage",
            resource=f"storageAccounts/{_storage_account_name}|diag"
        )
        _logger.info(f"Importing Azure Storage Account {_storage_account_name} diagnostics for table")
        self._import_resource(
            name=f'{_module_name}.azurerm_monitor_diagnostic_setting.table["table"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.Storage",
            resource=f"storageAccounts/{_storage_account_name}/tableServices/default/|diag"
        )
        for _key in ["blob", "file", "queue", "table"]:
            _logger.info(f"Importing Azure Storage Account {_storage_account_name} private endpoint for {_key}")
            self._import_resource(
                name=f'{_module_name}.azurerm_private_endpoint.this["{_key}"]',
                subscription_id=_vnet_subscription_id,
                resource_group_name=_vnet_resource_group_name,
                resource_type="Microsoft.Network",
                resource=f"privateEndpoints/pe-{_key}-{_storage_account_name}"

            )

    def _import(self):
        """
        Import the services.
        """
        
        _logger = self._logger
        
        _logger.info("Importing services...")

        _services_variables = self._services_variables

        _services_subscription_id = _services_variables["subscription_id"]
        _services_resource_group_name = _services_variables["resource_group_name"]

        _vnet_variables = self._vnet_variables
        _vnet_subscription_id = _vnet_variables["subscription_id"]
        _vnet_resource_group_name = _vnet_variables["resource_group_name"]

        _logger.info(f"Importing resource group {_services_resource_group_name}")
        self._import_resource_group(
            name="azurerm_resource_group.rg",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
        )

        
        _ai_foundry_name = _services_variables["ai_foundry"]["name"]
        _logger.info(f"Importing Azure AI Foundry {_ai_foundry_name}")
        self._import_resource(
            name="module.aifoundry[0].azurerm_ai_foundry.this",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.MachineLearningServices",
            resource=f"workspaces/{_ai_foundry_name}",
        )
        for _key, _value in _services_variables["ai_foundry"]["projects"].items():
            _project_name = _value["name"]
            _logger.info(f"Importing Azure AI Foundry project {_project_name}")
            self._import_resource(
                name=f'module.aifoundry[0].azurerm_ai_foundry_project.this["{_key}"]',
                subscription_id=_services_subscription_id,
                resource_group_name=_services_resource_group_name,
                resource_type="Microsoft.MachineLearningServices",
                resource=f"workspaces/{_project_name}",
            )
        

        _apim_name = _services_variables["apim"]["name"]
        _apim_subscription_id = _services_variables["apim"]["subscription_id"]
        _apim_resource_group_name = _services_variables["apim"]["resource_group_name"]
        for _key, _value in _services_variables["apim"]["apis"].items():
            _api_name = _value["name"]
            _logger.info(f"Importing Azure API Management API {_apim_name} for {_key}")
            self._import_resource(
                name=f"module.apimanagementapi[0].azurerm_api_management_api.{_key}",
                subscription_id=_apim_subscription_id,
                resource_group_name=_apim_resource_group_name,
                resource_type="Microsoft.ApiManagement",
                resource=f"service/{_apim_name}/apis/{_api_name};rev=1",
            )
            _logger.info(f"Importing Azure API Management API {_api_name} policy for {_key}")
            self._import_resource(
                name=f"module.apimanagementapi[0].azurerm_api_management_api_policy.{_key}",
                subscription_id=_apim_subscription_id,
                resource_group_name=_apim_resource_group_name,
                resource_type="Microsoft.ApiManagement",
                resource=f"service/{_apim_name}/apis/{_api_name}",
            )
            if _key == "ailanguage":
                _logger.info(f"Importing Azure API Management API operation redactpii")
                self._import_resource(
                    name="module.apimanagementapi[0].azurerm_api_management_api_operation.redactpii",
                    subscription_id=_apim_subscription_id,
                    resource_group_name=_apim_resource_group_name,
                    resource_type="Microsoft.ApiManagement",
                    resource=f"service/{_apim_name}/apis/{_api_name}/operations/redactpii",
                )


        _app_insights_name = _services_variables["app_insights"]["name"]
        _logger.info(f"Importing Azure Application Insights {_app_insights_name}")
        self._import_resource(
            name="module.appinsights[0].azurerm_application_insights.this",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.Insights",
            resource=f"components/{_app_insights_name}",
        )


        _ai_services_name = _services_variables["ai_services"]["name"]
        _logger.info(f"Importing Azure AI Services {_ai_services_name}")
        self._import_resource(
            name="module.aiservices[0].module.aiservices.azurerm_ai_services.this[0]",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.CognitiveServices",
            resource=f"accounts/{_ai_services_name}",
        )
        _logger.info(f"Importing Azure AI Services {_ai_services_name} diagnostics")
        self._import_resource(
            name='module.aiservices[0].module.aiservices.azurerm_monitor_diagnostic_setting.this["to_la"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.CognitiveServices",
            resource=f"accounts/{_ai_services_name}|tola_{_ai_services_name}"
        )
        for _key in ["aiservices", "openai", "cognitiveservices"]:
            _logger.info(f"Importing Azure AI Services {_ai_services_name} private endpoint for {_key}")
            self._import_resource(
                name=f'module.aiservices[0].module.aiservices.azurerm_private_endpoint.this["{_key}"]',
                subscription_id=_vnet_subscription_id,
                resource_group_name=_vnet_resource_group_name,
                resource_type="Microsoft.Network",
                resource=f"privateEndpoints/pe-{_key}-{_ai_services_name}",
            )
        

        _aml_name = _services_variables["aml"]["name"]
        _logger.info(f"Importing Azure Machine Learning {_aml_name}")
        self._import_resource(
            name="module.aml[0].module.azureml.azapi_resource.this[0]",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.MachineLearningServices",
            resource=f"workspaces/{_aml_name}",
        )
        for _key in ["api", "notebooks"]:
            _logger.info(f"Importing Azure Machine Learning {_aml_name} private endpoint for {_key}")
            self._import_resource(
                name=f'module.aml[0].module.azureml.azurerm_private_endpoint.this["{_key}"]',
                subscription_id=_vnet_subscription_id,
                resource_group_name=_vnet_resource_group_name,
                resource_type="Microsoft.Network",
                resource=f"privateEndpoints/pe-{_key}-aml",
            )
        

        _container_registry_name = _services_variables["container_registry"]["name"]
        _logger.info(f"Importing Azure Container Registry {_container_registry_name}")
        self._import_resource(
            name="module.cntreg[0].module.containerregistry.azurerm_container_registry.this",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.ContainerRegistry",
            resource=f"registries/{_container_registry_name}",
        )
        _logger.info(f"Importing Azure Container Registry {_container_registry_name} diagnostics")
        self._import_resource(
            name='module.cntreg[0].module.containerregistry.azurerm_monitor_diagnostic_setting.this["to_la"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.ContainerRegistry",
            resource=f"registries/{_container_registry_name}|tola_{_container_registry_name}"
        )
        _logger.info(f"Importing Azure Container Registry {_container_registry_name} private endpoint")
        self._import_resource(
            name='module.cntreg[0].module.containerregistry.azurerm_private_endpoint.this["primary"]',
            subscription_id=_vnet_subscription_id,
            resource_group_name=_vnet_resource_group_name,
            resource_type="Microsoft.Network",
            resource=f"privateEndpoints/pe-{_container_registry_name}",
        )


        _key_vault_name = _services_variables["key_vault"]["name"]
        _logger.info(f"Importing Azure Key Vault {_key_vault_name}")
        self._import_resource(
            name="module.keyvault[0].module.keyvault.azurerm_key_vault.this",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.KeyVault",
            resource=f"vaults/{_key_vault_name}",
        )
        _logger.info(f"Importing Azure Key Vault {_key_vault_name} diagnostics")
        self._import_resource(
            name='module.keyvault[0].module.keyvault.azurerm_monitor_diagnostic_setting.this["to_la"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.KeyVault",
            resource=f"vaults/{_key_vault_name}|tola_{_key_vault_name}"
        )
        _logger.info(f"Importing Azure Key Vault {_key_vault_name} private endpoint")
        self._import_resource(
            name='module.keyvault[0].module.keyvault.azurerm_private_endpoint.this["pe_endpoint"]',
            subscription_id=_vnet_subscription_id,
            resource_group_name=_vnet_resource_group_name,
            resource_type="Microsoft.Network",
            resource=f"privateEndpoints/pe-{_key_vault_name}",
        )


        _ai_language_name = _services_variables["ai_language"]["name"]
        _logger.info(f"Importing Azure AI Language {_ai_language_name}")
        self._import_resource(
            name="module.language[0].module.ai_language.azurerm_cognitive_account.this[0]",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.CognitiveServices",
            resource=f"accounts/{_ai_language_name}",
        )
        _logger.info(f"Importing Azure AI Language {_ai_language_name} diagnostics")
        self._import_resource(
            name='module.language[0].module.ai_language.azurerm_monitor_diagnostic_setting.this["to_la"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.CognitiveServices",
            resource=f"accounts/{_ai_language_name}|tola_{_ai_language_name}"
        )
        _logger.info(f"Importing Azure AI Language {_ai_language_name} private endpoint")
        self._import_resource(
            name='module.language[0].module.ai_language.azurerm_private_endpoint.this["pe_endpoint"]',
            subscription_id=_vnet_subscription_id,
            resource_group_name=_vnet_resource_group_name,
            resource_type="Microsoft.Network",
            resource=f"privateEndpoints/pe-{_ai_language_name}",
        )


        _open_ai_name = _services_variables["open_ai"]["name"]
        _logger.info(f"Importing Azure OpenAI {_open_ai_name}")
        self._import_resource(
            name="module.openai[0].module.openai.azurerm_cognitive_account.this[0]",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.CognitiveServices",
            resource=f"accounts/{_open_ai_name}",
        )
        _logger.info(f"Importing Azure OpenAI {_open_ai_name} diagnostics")
        self._import_resource(
            name='module.openai[0].module.openai.azurerm_monitor_diagnostic_setting.this["to_la"]',
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.CognitiveServices",
            resource=f"accounts/{_open_ai_name}|tola_{_open_ai_name}"
        )
        _logger.info(f"Importing Azure OpenAI {_open_ai_name} private endpoint")
        self._import_resource(
            name='module.openai[0].module.openai.azurerm_private_endpoint.this["pe_endpoint"]',
            subscription_id=_vnet_subscription_id,
            resource_group_name=_vnet_resource_group_name,
            resource_type="Microsoft.Network",
            resource=f"privateEndpoints/pe-{_open_ai_name}",
        )
        for _key, _value in _services_variables["open_ai"]["deployments"].items():
            _deployment_name = _value["name"]
            _logger.info(f"Importing Azure OpenAI deployment {_key}")
            self._import_resource(
                name=f'module.openai[0].module.openai.azurerm_cognitive_deployment.this["{_key}"]',
                subscription_id=_services_subscription_id,
                resource_group_name=_services_resource_group_name,
                resource_type="Microsoft.CognitiveServices",
                resource=f"accounts/{_open_ai_name}/deployments/{_deployment_name}",
            )


        _ai_foundry_storage_account_name = _services_variables["ai_foundry"]["storage_account_name"]
        self._import_storage(
            storage_subscription_id=_services_subscription_id,
            storage_resource_group_name=_services_resource_group_name,
            storage_account_name=_ai_foundry_storage_account_name,
            vnet_subscription_id=_vnet_subscription_id,
            vnet_resource_group_name=_vnet_resource_group_name,
            module_name="module.aifoundry[0].module.ai_foundry_storage.module.this"
        )

        _aml_storage_account_name = _services_variables["aml"]["storage_account_name"]
        self._import_storage(
            storage_subscription_id=_services_subscription_id,
            storage_resource_group_name=_services_resource_group_name,
            storage_account_name=_aml_storage_account_name,
            vnet_subscription_id=_vnet_subscription_id,
            vnet_resource_group_name=_vnet_resource_group_name,
            module_name="module.aml[0].module.aml_storage.module.this",
        )
        _ai_services_storage_account_name = _services_variables["ai_services"]["storage_account_name"]
        self._import_storage(
            storage_subscription_id=_services_subscription_id,
            storage_resource_group_name=_services_resource_group_name,
            storage_account_name=_ai_services_storage_account_name,
            vnet_subscription_id=_vnet_subscription_id,
            vnet_resource_group_name=_vnet_resource_group_name,
            module_name="module.aiservices[0].module.ai_services_storage.module.this"
        )

        _uai_name = _services_variables["uai"]["name"]
        _logger.info(f"Importing Azure UAI {_uai_name}")
        self._import_resource(
            name=" module.uai[0].module.this.azurerm_user_assigned_identity.this",
            subscription_id=_services_subscription_id,
            resource_group_name=_services_resource_group_name,
            resource_type="Microsoft.ManagedIdentity",
            resource=f"userAssignedIdentities/{_uai_name}",
        )

if __name__ == "__main__":
    _import_state = ImportState()
    _import_state._import()
