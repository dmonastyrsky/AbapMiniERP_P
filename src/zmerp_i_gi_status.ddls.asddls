@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Issue Status Text'
@ObjectModel.dataCategory: #TEXT

define view entity ZMERP_I_GI_STATUS
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZMERP_GI_STATUS' )
{
  @EndUserText.label: 'Status Code'
  key value_low as Status,

  @Semantics.text: true
  @EndUserText.label: 'Status Description'
  text          as StatusText
}
where language = $session.system_language
