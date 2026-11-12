@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Issue Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['DocumentNumber']

define root view entity ZMERP_C_GOODSISSUE
  provider contract transactional_query
  as projection on ZMERP_R_GOODSISSUE
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
        additionalBinding: [{ element: 'IsCustomer', localConstant: 'X', usage: #FILTER }],
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

      @ObjectModel.text.element: [ 'SoDocumentNumber' ]
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZMERP_I_SO_VH', element: 'DocumentUUID' },
        additionalBinding: [
          { localElement: 'CompanyCode',         element: 'CompanyCode',         usage: #FILTER_AND_RESULT },
          { localElement: 'WarehouseCode',       element: 'WarehouseCode',       usage: #FILTER_AND_RESULT },
          { localElement: 'BusinessPartnerCode', element: 'BusinessPartnerCode', usage: #FILTER_AND_RESULT },
          { localConstant: 'X',                  element: 'CanIssueGoods',       usage: #FILTER }
        ],
        useForValidation: true
      }]
      SoReferenceUUID,

      @EndUserText.label: 'Sales Order Number'
      _SalesOrder.DocumentNumber as SoDocumentNumber,

      @Search.defaultSearchElement: true
      CustomerReference,

      @ObjectModel.text.element: ['StatusDescription']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMERP_I_GI_STATUS_VH', element: 'Status' }, useForValidation: true }]
      Status,

      @EndUserText.label: 'Status Description'
      _Status.Description as StatusDescription,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Items           : redirected to composition child ZMERP_C_GOODSISSUEITM,
      _CompanyCode     : redirected to ZMERP_C_COMPANY_CODE,
      _Warehouse       : redirected to ZMERP_C_WAREHOUSE,
      _BusinessPartner : redirected to ZMERP_C_BUS_PARTNER,
      _SalesOrder      : redirected to ZMERP_C_SALESORDER,
      _Currency,
      _Status
}
