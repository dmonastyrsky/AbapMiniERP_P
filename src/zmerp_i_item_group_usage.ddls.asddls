@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Group Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_ITEM_GROUP_USAGE
  as select from ZMERP_R_ITEM
{
  key ItemGroupCode                       as ItemGroupCode,
  key ItemCode                            as RefEntityKey,
  key cast( 'Item' as zmerp_entity_name ) as UsedInEntity
}
where ItemGroupCode is not initial
