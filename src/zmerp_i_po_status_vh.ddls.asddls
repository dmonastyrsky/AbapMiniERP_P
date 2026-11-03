@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order Status Value Help'
@ObjectModel.dataCategory: #TEXT
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true

@UI.presentationVariant: [{
  sortOrder: [{
    by: 'SortOrder',
    direction: #ASC
  }]
}]

define view entity ZMERP_I_PO_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZMERP_PO_STATUS' )
{
  @EndUserText.label: 'Status'
  @UI.hidden: true
  key value_low   as Status,

  @Semantics.language: true
  @UI.hidden: true
  key language    as Language,

  @EndUserText.label: 'Description'
  @Semantics.text: true
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  text            as Description,

  @UI.hidden: true
  case value_low
    when 'N' then 1
    when 'A' then 2
    when 'P' then 3
    when 'C' then 4
    when 'X' then 5
    else 99
  end             as SortOrder
}
where language = $session.system_language
