@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company Code Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['CompanyCode']

define root view entity ZMERP_C_COMPANY_CODE
  provider contract transactional_query
  as projection on ZMERP_R_COMPANY_CODE
{
      @ObjectModel.text.element: [ 'CompanyName' ]
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key CompanyCode,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      CompanyName,
      
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      CompanyPrefix,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CountryVH', element: 'Country' }, useForValidation: true }]
      @ObjectModel.text.element: [ 'CountryName' ]
      Country,
      _CountryText.CountryName as CountryName,
      
      IsBlocked,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _Currency,
      _Country,
      _CountryText,
      _CurrencyText
}
