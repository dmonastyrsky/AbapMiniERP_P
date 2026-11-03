CLASS zcl_merp_md_warehouse_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_warehouse_sel.

  PRIVATE SECTION.
    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_warehouse_sel=>tt_warehouse_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_warehouse_sel=>tt_warehouse_keys.
ENDCLASS.

CLASS zcl_merp_md_warehouse_sel IMPLEMENTATION.

  METHOD zif_merp_md_warehouse_sel~read_warehouse.
    DATA(lt_warehouses) = zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( ( WarehouseCode = iv_warehouse_code ) )
    ).

    " An initial code is dropped by prepare_keys, so this one check also covers empty input
    TRY.
        rs_warehouse = lt_warehouses[ WarehouseCode = iv_warehouse_code ].
      CATCH cx_sy_itab_line_not_found.
        RAISE EXCEPTION TYPE zcx_merp_md
          EXPORTING
            textid   = zcx_merp_md=>warehouse_not_found
            attr1    = CONV string( iv_warehouse_code )
            severity = if_abap_behv_message=>severity-error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_merp_md_warehouse_sel~read_warehouses.
    DATA(lt_clean_keys) = prepare_keys( it_warehouse_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT wh~*
      FROM zmerp_r_warehouse AS wh
      INNER JOIN @lt_clean_keys AS keys ON wh~WarehouseCode = keys~WarehouseCode
      INTO TABLE @rt_warehouses.
  ENDMETHOD.

  METHOD zif_merp_md_warehouse_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_warehouse_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DISTINCT: one row per code and using entity, however many documents use the code
    SELECT DISTINCT usage~WarehouseCode, usage~UsedInEntity, usage~IsDocument
      FROM zmerp_i_warehouse_usage AS usage
      INNER JOIN @lt_clean_keys AS keys ON usage~WarehouseCode = keys~WarehouseCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_usages.
  ENDMETHOD.

  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE WarehouseCode IS INITIAL.
    SORT rt_keys BY WarehouseCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING WarehouseCode.
  ENDMETHOD.

ENDCLASS.

