@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company Code Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

// IsDocument: the code is used in a document (critical fields read-only); master data usage only blocks delete

define view entity ZMERP_I_COMPANY_CODE_USAGE
  as select from ZMERP_R_WAREHOUSE
{
  key CompanyCode,
  key cast( WarehouseCode as abap.char(40) )   as RefEntityKey,
  key cast( 'Warehouse' as zmerp_entity_name ) as UsedInEntity,
      cast( ' ' as abap_boolean preserving type )            as IsDocument
}
where CompanyCode is not initial

union all select from ZMERP_R_PURCHASEORDER
{
  key CompanyCode,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Purchase Order' as zmerp_entity_name )     as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where CompanyCode is not initial

union all select from ZMERP_R_GOODSRECEIPT
{
  key CompanyCode,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Goods Receipt' as zmerp_entity_name )      as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where CompanyCode is not initial

union all select from ZMERP_R_SALESORDER
{
  key CompanyCode,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Sales Order' as zmerp_entity_name )        as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where CompanyCode is not initial

union all select from ZMERP_R_GOODSISSUE
{
  key CompanyCode,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Goods Issue' as zmerp_entity_name )        as UsedInEntity,
      cast( 'X' as abap_boolean preserving type )       as IsDocument
}
where CompanyCode is not initial
