@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Warehouse Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_WAREHOUSE_USAGE
  as select from ZMERP_R_PURCHASEORDER
{
  key WarehouseCode                                    as WarehouseCode,
  key DocumentUUID                                     as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Purchase Order' as zmerp_entity_name )    as UsedInEntity
}
where WarehouseCode is not initial
