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

    def _import(self):
        """
        Import the services.
        """
        
        _logger = self._logger
        
        _logger.info("Importing services...")

        _services_variables = self._services_variables
        _vnet_variables = self._vnet_variables

        _vnet_subscription_id = _vnet_variables["subscription_id"]
        _vnet_resource_group_name = _vnet_variables["resource_group_name"]
        _vnet_name = _vnet_variables["name"]


        _services_subscription_id = _services_variables["subscription_id"]
        _services_resource_group_name = _services_variables["resource_group_name"]

        _logger.info(f"Importing resource group {_services_resource_group_name}")
        self._import_resource(
            name="module.log.azurerm_resource_group.avmrg",
            resource_id=f"/subscriptions/{_services_subscription_id}/resourceGroups/{_services_resource_group_name}",
        )