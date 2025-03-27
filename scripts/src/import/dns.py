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
        self._import_resource_group(
            name="module.dns.azurerm_resource_group.avmrg",
            subscription_id=_subscription_id,
            resource_group_name=_resource_group_name,
        )

        for _key, _value in _dns_variables["domain_names"].items():
            _logger.info(f"Importing DNS variable {_key} with value {_value}")
            self._import_resource(
                name=f'module.dns.module.private_dns_zones["{_key}"].azurerm_private_dns_zone.this',
                subscription_id=_subscription_id,
                resource_group_name=_resource_group_name,
                resource_type="Microsoft.Network/privateDnsZones",
                resource=_value,
            )


if __name__ == "__main__":
    _import_state = ImportState()
    _import_state._import()
