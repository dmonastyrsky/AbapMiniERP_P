@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZMERP_I_SO_VH
  as select from ZMERP_R_SALESORDER
{
      @UI.hidden: true
  key DocumentUUID,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @Search.fuzzinessThreshold: 0.7
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      DocumentNumber,

      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      DocumentDate,

      @ObjectModel.text.element: [ 'PartnerName' ]
      @UI.textArrangement: #TEXT_ONLY
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 30, importance: #HIGH }]
      BusinessPartnerCode,
      _BusinessPartner.PartnerName as PartnerName,

      @ObjectModel.text.element: [ 'WarehouseName' ]
      @UI.textArrangement: #TEXT_ONLY
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 40, importance: #MEDIUM }]
      WarehouseCode,
      _Warehouse.WarehouseName as WarehouseName,

      @ObjectModel.text.element: [ 'CompanyName' ]
      @UI.textArrangement: #TEXT_ONLY
      @UI.lineItem: [{ position: 50, importance: #LOW }]
      CompanyCode,
      _CompanyCode.CompanyName as CompanyName,

      @ObjectModel.text.element: [ 'StatusDescription' ]
      @UI.textArrangement: #TEXT_ONLY
      @UI.lineItem: [{ position: 60, importance: #MEDIUM }]
      Status,
      _Status.Description as StatusDescription,

      @UI.hidden: true
      CurrencyCode,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      @UI.lineItem: [{ position: 70, importance: #HIGH }]
      TotalGrossAmount,

      // Goods issue is possible for 'Open' and 'In Process' documents
      // (same rule as ZCL_MERP_DOC_SO_LIFECYCLE=>CAN_ISSUE_GOODS)
      @UI.hidden: true
      cast( case Status
              when 'N' then 'X'
              when 'P' then 'X'
              else ' '
            end as abap_boolean preserving type ) as CanIssueGoods
}
where
  Status <> 'X'
