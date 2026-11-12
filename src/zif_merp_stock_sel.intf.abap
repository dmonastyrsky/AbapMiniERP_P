"! Stock selector. Balances are read from the movement journal (ZMERP_R_STOCK_BALANCE):
"! only posted documents have movements, so drafts and unsaved changes are not visible.
INTERFACE zif_merp_stock_sel
  PUBLIC.

  TYPES: BEGIN OF ty_stock_key,
           CompanyCode   TYPE zmerp_company_code,
           WarehouseCode TYPE zmerp_warehouse_code,
           ItemCode      TYPE zmerp_item_code,
           UnitOfMeasure TYPE zmerp_unit,
         END OF ty_stock_key,
         tt_stock_keys TYPE STANDARD TABLE OF ty_stock_key WITH EMPTY KEY.

  "! Current quantity and value (company currency) of a stock key
  TYPES: BEGIN OF ty_balance,
           CompanyCode   TYPE zmerp_company_code,
           WarehouseCode TYPE zmerp_warehouse_code,
           ItemCode      TYPE zmerp_item_code,
           UnitOfMeasure TYPE zmerp_unit,
           Quantity      TYPE zmerp_quantity,
           StockValue    TYPE zmerp_net_amount,
         END OF ty_balance,
         tt_balances TYPE HASHED TABLE OF ty_balance
                     WITH UNIQUE KEY CompanyCode WarehouseCode ItemCode UnitOfMeasure.

  "! Reads the current stock quantity and value per company, warehouse, item and unit
  "! (all movements, no date restriction). Keys without stock are not returned.
  "! @parameter it_stock_keys | Keys to read (duplicates and keys without item are ignored)
  "! @parameter rt_balances   | Current quantity and value per key
  METHODS read_balances
    IMPORTING it_stock_keys      TYPE tt_stock_keys
    RETURNING VALUE(rt_balances) TYPE tt_balances.

ENDINTERFACE.
