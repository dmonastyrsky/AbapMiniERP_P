@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_ITEM_USAGE
  as select from zmerp_item
{
  key item_code                                as ItemCode,
  key cast( '' as abap.char(10) )              as RefEntityKey,
  key cast( 'Item' as zmerp_entity_name )      as UsedInEntity
}
where 1 = 0 //Dummy
