@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZMERP_I_ITEM_VH
  as select from ZMERP_R_ITEM
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

      @ObjectModel.text.element: [ 'ItemTypeDescription' ]
      @UI.textArrangement: #TEXT_ONLY
      ItemTypeCode,
      _ItemType.Description        as ItemTypeDescription,

      @ObjectModel.text.element: [ 'ItemGroupDescription' ]
      @UI.textArrangement: #TEXT_ONLY
      ItemGroupCode,
      _ItemGroup.Description       as ItemGroupDescription,

      @ObjectModel.text.element: [ 'DefaultVATRateDescription' ]
      @UI.textArrangement: #TEXT_ONLY  
      DefaultVatCode,  
      _DefaultVATRate.Description as DefaultVATRateDescription
}

where
  IsBlocked = ''
