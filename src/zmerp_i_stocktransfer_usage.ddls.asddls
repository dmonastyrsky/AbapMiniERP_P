@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Transfer Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMERP_I_STOCKTRANSFER_USAGE
  as select from ZMERP_R_STOCKTRANSFER
{
  key DocumentUUID                                  as DocumentUUID,
  key cast( '' as abap.char(10) )                   as RefEntityKey,
  key cast( 'Stock Transfer' as zmerp_entity_name ) as UsedInEntity
}
where 1 = 0
