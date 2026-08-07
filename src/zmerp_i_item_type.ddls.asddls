@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Type'
@ObjectModel.dataCategory: #TEXT

define view entity ZMERP_I_ITEM_TYPE
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZMERP_ITEM_TYPE' )
{
  @EndUserText.label: 'Item Type Code'
  key value_low as ItemTypeCode,

  @Semantics.text: true
  @EndUserText.label: 'Item Type Description'
  text          as ItemTypeText
}
where language = $session.system_language
