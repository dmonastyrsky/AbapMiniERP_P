@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_PURCHASEORDER_USAGE
  as select from ZMERP_R_PURCHASEORDER
{
  key DocumentUUID                             as DocumentUUID,
  key cast( '' as abap.char(10) )              as RefEntityKey,
  key cast( 'Purchase Order' as zmerp_entity_name ) as UsedInEntity
}
where 1 = 0 // Dummy implementation for future dependency checks
