CLASS zcl_merp_stock_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_stock_sel.

  PRIVATE SECTION.
    TYPES tt_unique_keys TYPE HASHED TABLE OF zif_merp_stock_sel=>ty_stock_key
                         WITH UNIQUE KEY CompanyCode WarehouseCode ItemCode UnitOfMeasure.
ENDCLASS.


CLASS zcl_merp_stock_sel IMPLEMENTATION.

  METHOD zif_merp_stock_sel~read_balances.
    DATA lt_keys TYPE tt_unique_keys.

    " Duplicate keys are skipped by the unique key; a key without item cannot have stock
    LOOP AT it_stock_keys INTO DATA(ls_key) WHERE ItemCode IS NOT INITIAL.
      INSERT ls_key INTO TABLE lt_keys.
    ENDLOOP.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    " The balance view also groups by currency: SUM gives one row per key
    " (stock is kept in the company currency only, so the value sum is in one currency)
    SELECT bal~CompanyCode, bal~WarehouseCode, bal~ItemCode, bal~UnitOfMeasure,
           SUM( bal~Quantity ) AS Quantity,
           SUM( bal~StockValue ) AS StockValue
      FROM zmerp_r_stock_balance AS bal
      INNER JOIN @lt_keys AS key ON  bal~CompanyCode   = key~CompanyCode
                                 AND bal~WarehouseCode = key~WarehouseCode
                                 AND bal~ItemCode      = key~ItemCode
                                 AND bal~UnitOfMeasure = key~UnitOfMeasure
      GROUP BY bal~CompanyCode, bal~WarehouseCode, bal~ItemCode, bal~UnitOfMeasure
      INTO CORRESPONDING FIELDS OF TABLE @rt_balances.
  ENDMETHOD.

ENDCLASS.
