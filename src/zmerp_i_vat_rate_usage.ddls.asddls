@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VAT Rate Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_VAT_RATE_USAGE
  as select from ZMERP_R_ITEM_GROUP
{
  key DefaultVatCode                          as VatCode,
  key ItemGroupCode                           as RefEntityKey,
  key cast( 'Item Group' as zmerp_entity_name ) as UsedInEntity
}
where DefaultVatCode is not initial

union all select from ZMERP_R_ITEM
{
  key DefaultVatCode                          as VatCode,
  key ItemCode                                as RefEntityKey,
  key cast( 'Item' as zmerp_entity_name )      as UsedInEntity
}
where DefaultVatCode is not initial
