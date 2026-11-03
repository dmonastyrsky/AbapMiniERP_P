@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Type Value Help and Text'
@ObjectModel.dataCategory: #TEXT
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZMERP_I_ITEM_TYPE_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZMERP_ITEM_TYPE' )
{
  @EndUserText.label: 'Item Type'
  @UI.hidden: true
  key value_low   as ItemTypeCode,
  
  @Semantics.language: true
  @UI.hidden: true
  key language    as Language,
  
  @EndUserText.label: 'Description'
  @Semantics.text: true
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  text        as Description
}
where language = $session.system_language
