@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VAT Rate Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

// IsDocument: the code is used in a document (critical fields read-only); master data usage only blocks delete

define view entity ZMERP_I_VAT_RATE_USAGE
  as select from ZMERP_R_ITEM_GROUP
{
  key DefaultVatCode                            as VatCode,
  key cast( ItemGroupCode as abap.char(40) )    as RefEntityKey,
  key cast( 'Item Group' as zmerp_entity_name ) as UsedInEntity,
      cast( ' ' as abap_boolean preserving type )            as IsDocument
}
where DefaultVatCode is not initial

union all select from ZMERP_R_ITEM
{
  key DefaultVatCode                            as VatCode,
  key cast( ItemCode as abap.char(40) )         as RefEntityKey,
  key cast( 'Item' as zmerp_entity_name )       as UsedInEntity,
      cast( ' ' as abap_boolean preserving type )            as IsDocument
}
where DefaultVatCode is not initial

union all select from ZMERP_R_PURCHASEORDERITM
{
  key VatCode                                            as VatCode,
  key cast( bintohex( ItemUUID ) as abap.char(40) )      as RefEntityKey,
  key cast( 'Purchase Order Item' as zmerp_entity_name ) as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )        as IsDocument
}
where VatCode is not initial

union all select from ZMERP_R_GOODSRECEIPTITM
{
  key VatCode                                           as VatCode,
  key cast( bintohex( ItemUUID ) as abap.char(40) )     as RefEntityKey,
  key cast( 'Goods Receipt Item' as zmerp_entity_name ) as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where VatCode is not initial
