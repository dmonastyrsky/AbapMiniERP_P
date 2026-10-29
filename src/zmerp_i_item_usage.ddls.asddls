@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_ITEM_USAGE
  as select from ZMERP_R_PURCHASEORDERITM
{
  key ItemCode                                           as ItemCode,
  key ItemUUID                                           as ItemUUID,
  key cast( bintohex( ItemUUID ) as abap.char(40) )      as RefEntityKey,
  key cast( 'Purchase Order Item' as zmerp_entity_name ) as UsedInEntity
}
where ItemCode is not initial
