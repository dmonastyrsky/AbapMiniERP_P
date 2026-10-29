@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company Code Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_COMPANY_CODE_USAGE
  as select from ZMERP_R_WAREHOUSE
{
  key CompanyCode,
  key cast( WarehouseCode as abap.char(40) )   as RefEntityKey,
  key cast( 'Warehouse' as zmerp_entity_name ) as UsedInEntity
}
where CompanyCode is not initial

union all select from ZMERP_R_PURCHASEORDER
{
  key CompanyCode,
  key cast( bintohex( DocumentUUID ) as abap.char(40) ) as RefEntityKey,
  key cast( 'Purchase Order' as zmerp_entity_name )      as UsedInEntity
}
where CompanyCode is not initial
