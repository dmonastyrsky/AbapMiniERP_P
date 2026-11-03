@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VAT Rate Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['VatCode']

define root view entity ZMERP_C_VAT_RATE
  provider contract transactional_query
  as projection on ZMERP_R_VAT_RATE
{
      @ObjectModel.text.element: ['Description']      
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key VatCode,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      Description,

      Percentage,
      
      IsBlocked,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
