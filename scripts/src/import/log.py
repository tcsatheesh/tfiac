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

    def _import(
        self,
    ):
        _logger = self._logger
        _logger.info("Importing Log Analytics state...")

        _log_variables = self._log_variables

        _subscription_id = _log_variables["subscription_id"]
        _resource_group_name = _log_variables["resource_group_name"]
        _workspace_name = _log_variables["workspace_name"]

        _logger.info(f"Importing resource group {_resource_group_name}")
        self._import_resource(
            name="module.log.azurerm_resource_group.avmrg",
            resource_id=f"/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}",
        )
        _logger.info(
            f"Importing Log Analytics workspace {_workspace_name} in resource group {_resource_group_name}"
        )
        self._import_resource(
            name="module.log.module.log_analytics_workspace.azurerm_log_analytics_workspace.this",
            resource_id=f"/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/{_workspace_name}",
        )


if __name__ == "__main__":
    _import_state = ImportState()
    _import_state._import()
