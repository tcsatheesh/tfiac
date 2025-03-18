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
        _logger.info("Importing DNS state...")

        _dns_variables = self._dns_variables

        _subscription_id = _dns_variables["subscription_id"]
        _resource_group_name = _dns_variables["resource_group_name"]

        _logger.info(f"Importing resource group {_resource_group_name}")
        self._import_resource(
            name="module.log.azurerm_resource_group.avmrg",
            resource_id=f"/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}",
        )

        for _key, _value in _dns_variables["domain_names"].items():
            _logger.info(f"Importing DNS variable {_key} with value {_value}")
            self._import_resource(
                name=f'module.dns.module.private_dns_zones["{_key}"].azurerm_private_dns_zone.this',
                resource_id=f"/subscriptions/{_subscription_id}/resourceGroups/{_resource_group_name}/providers/Microsoft.Network/privateDnsZones/{_value}",
            )


if __name__ == "__main__":
    _import_state = ImportState()
    _import_state._import()
