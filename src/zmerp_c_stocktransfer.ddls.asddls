@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Transfer Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['DocumentNumber']

define root view entity ZMERP_C_STOCKTRANSFER
  provider contract transactional_query
  as projection on ZMERP_R_STOCKTRANSFER
{
      @ObjectModel.text.element: [ 'DocumentNumber' ]
  key DocumentUUID,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      DocumentNumber,

      DocumentDate,
      PostingDate,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_COMPANY_CODE_VH', element: 'CompanyCode' }, useForValidation: true }]
      CompanyCode,

      @EndUserText.label: 'Issuing Warehouse'
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_WAREHOUSE_VH', element: 'WarehouseCode' },
        additionalBinding: [{ localElement: 'CompanyCode', element: 'CompanyCode', usage: #FILTER_AND_RESULT }],
        useForValidation: true
      }]
      WarehouseCode,

      ResponsiblePerson,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Remarks,

      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_WAREHOUSE_VH', element: 'WarehouseCode' },
        additionalBinding: [{ localElement: 'CompanyCode', element: 'CompanyCode', usage: #FILTER_AND_RESULT }],
        useForValidation: true
      }]
      ReceivingWarehouseCode,

      @ObjectModel.text.element: ['StatusDescription']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_ST_STATUS_VH', element: 'Status' }, useForValidation: true }]
      Status,

      @EndUserText.label: 'Status Description'
      _Status.Description as StatusDescription,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Items              : redirected to composition child ZMERP_C_STOCKTRANSFERITM,
      _CompanyCode        : redirected to ZMERP_C_COMPANY_CODE,
      _Warehouse          : redirected to ZMERP_C_WAREHOUSE,
      _ReceivingWarehouse : redirected to ZMERP_C_WAREHOUSE,
      _Status
}
