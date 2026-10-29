@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'PartnerCode' ]

define root view entity ZMERP_C_BUS_PARTNER
  provider contract transactional_query
  as projection on ZMERP_R_BUS_PARTNER
{
      @ObjectModel.text.element: ['PartnerName']
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key PartnerCode,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      PartnerName,

      IsCustomer,
      IsSupplier,

      @Search.defaultSearchElement: true
      TaxNumber,

      Address,      
      City,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CountryVH', element: 'Country' }, useForValidation: true }]
      @ObjectModel.text.element: [ 'CountryName' ]
      Country,
      _CountryText.CountryName as CountryName,

      Phone,
      Email,
      
      IsBlocked,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _Country,
      _CountryText
}
