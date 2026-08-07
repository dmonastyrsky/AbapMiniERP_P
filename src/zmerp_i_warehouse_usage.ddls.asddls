@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Warehouse Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_WAREHOUSE_USAGE
  as select from zmerp_warehouse
{
  key warehouse_code                           as WarehouseCode,
  key cast( '' as abap.char(10) )              as RefEntityKey,
  key cast( 'Warehouse' as zmerp_entity_name ) as UsedInEntity
}
where 1 = 0 //Dummy
