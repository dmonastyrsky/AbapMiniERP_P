@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Warehouse Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_WAREHOUSE_USAGE
  as select from ZMERP_R_PURCHASEORDER
{
  key WarehouseCode                                    as WarehouseCode,
  key DocumentUUID                                     as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Purchase Order' as zmerp_entity_name )    as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where WarehouseCode is not initial

union all select from ZMERP_R_GOODSRECEIPT
{
  key WarehouseCode                                    as WarehouseCode,
  key DocumentUUID                                     as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Goods Receipt' as zmerp_entity_name )     as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where WarehouseCode is not initial

union all select from ZMERP_R_SALESORDER
{
  key WarehouseCode                                    as WarehouseCode,
  key DocumentUUID                                     as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Sales Order' as zmerp_entity_name )       as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where WarehouseCode is not initial

union all select from ZMERP_R_GOODSISSUE
{
  key WarehouseCode                                    as WarehouseCode,
  key DocumentUUID                                     as DocumentUUID,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Goods Issue' as zmerp_entity_name )       as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where WarehouseCode is not initial
