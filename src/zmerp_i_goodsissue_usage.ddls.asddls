@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Issue Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_GOODSISSUE_USAGE
  as select from ZMERP_R_GOODSISSUE
{
  key DocumentUUID                               as DocumentUUID,
  key cast( '' as abap.char(10) )                as RefEntityKey,
  key cast( 'Goods Issue' as zmerp_entity_name ) as UsedInEntity
}
where 1 = 0 // Dummy implementation for future dependency checks
