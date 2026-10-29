@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['ItemCode']

define root view entity ZMERP_C_ITEM
  provider contract transactional_query
  as projection on ZMERP_R_ITEM
{
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      key ItemCode,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      Description,
      
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.8
      Article,

      @ObjectModel.text.element: ['ItemTypeDescription']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_ITEM_TYPE_VH', element: 'ItemTypeCode' }, useForValidation: true }]
      ItemTypeCode,
      
      @EndUserText.label: 'Item Type Description'
      _ItemType.Description as ItemTypeDescription,
      
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_ITEM_GROUP_VH', element: 'ItemGroupCode' }, useForValidation: true }]
      ItemGroupCode,
      
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_VAT_RATE_VH', element: 'VatCode' }, useForValidation: true }]
      DefaultVatCode,
            
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' }, useForValidation: true }]
      BaseUnitOfMeasure,
      
      IsBlocked,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Redirected associations */
      _ItemGroup      : redirected to ZMERP_C_ITEM_GROUP,
      _DefaultVATRate : redirected to ZMERP_C_VAT_RATE,
      
      /* Exposed text association */
      _ItemType
}
