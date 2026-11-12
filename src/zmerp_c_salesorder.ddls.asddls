@EndUserText.label: 'Sales Order Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['DocumentNumber']

define root view entity ZMERP_C_SALESORDER
  provider contract transactional_query
  as projection on ZMERP_R_SALESORDER
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

      @Consumption.valueHelpDefinition: [{
      entity: { name: 'ZMERP_I_WAREHOUSE_VH', element: 'WarehouseCode' },
      additionalBinding: [{ localElement: 'CompanyCode', element: 'CompanyCode', usage: #FILTER_AND_RESULT }],
      useForValidation: true
      }]
      WarehouseCode,

      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_BUS_PARTNER_VH', element: 'PartnerCode' },
        additionalBinding: [{ element: 'IsCustomer', localConstant: 'X', usage: #FILTER}],
        useForValidation: true
      }]
      BusinessPartnerCode,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,

      TotalNetAmount,
      TotalGrossAmount,

      ResponsiblePerson,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Remarks,

      @Search.defaultSearchElement: true
      CustomerReference,

      @ObjectModel.text.element: ['StatusDescription']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_SO_STATUS_VH', element: 'Status' }, useForValidation: true }]
      Status,

      @EndUserText.label: 'Status Description'
      _Status.Description as StatusDescription,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Items           : redirected to composition child ZMERP_C_SALESORDERITM,
      _CompanyCode     : redirected to ZMERP_C_COMPANY_CODE,
      _Warehouse       : redirected to ZMERP_C_WAREHOUSE,
      _BusinessPartner : redirected to ZMERP_C_BUS_PARTNER,

      _Currency,

      _Status
}
