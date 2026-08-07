@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner Usage Dependencies'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZMERP_I_BUS_PARTNER_USAGE
  as select from zmerp_bus_part
{
  key partner_code                             as PartnerCode,
  key cast( '' as abap.char(10) )              as RefEntityKey,
  key cast( 'Business Partner' as zmerp_entity_name ) as UsedInEntity
}
where 1 = 0 //Dummy
