CLASS zcl_merp_md_warehouse_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_warehouse_sel.

  PRIVATE SECTION.
    TYPES tt_warehouse_keys_unique TYPE HASHED TABLE OF zif_merp_md_warehouse_sel=>ty_warehouse_key
                                        WITH UNIQUE KEY WarehouseCode.

    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_warehouse_sel=>tt_warehouse_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_warehouse_sel=>tt_warehouse_keys.
ENDCLASS.


CLASS zcl_merp_md_warehouse_sel IMPLEMENTATION.

  METHOD zif_merp_md_warehouse_sel~read_warehouse.
    IF iv_warehouse_code IS INITIAL.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>warehouse_not_found
          attr1    = CONV string( iv_warehouse_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.

    DATA(lt_warehouses) = zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( ( WarehouseCode = iv_warehouse_code ) )
    ).

    ASSIGN lt_warehouses[ WarehouseCode = iv_warehouse_code ] TO FIELD-SYMBOL(<ls_detail>).
    IF sy-subrc = 0.
      rs_warehouse = <ls_detail>.
    ELSE.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>warehouse_not_found
          attr1    = CONV string( iv_warehouse_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.
  ENDMETHOD.


  METHOD zif_merp_md_warehouse_sel~read_warehouses.
    DATA(lt_clean_keys) = prepare_keys( it_warehouse_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT wh~WarehouseCode,
           wh~WarehouseName,
           wh~CompanyCode,
           wh~IsBlocked,
           wh~CreatedBy,
           wh~CreatedAt,
           wh~LocalLastChangedBy,
           wh~LocalLastChangedAt,
           wh~LastChangedAt
      FROM zmerp_r_warehouse AS wh
      INNER JOIN @lt_clean_keys AS keys ON wh~WarehouseCode = keys~WarehouseCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_warehouses.
  ENDMETHOD.


  METHOD zif_merp_md_warehouse_sel~validate_warehouses.
    DATA lt_existing_keys TYPE tt_warehouse_keys_unique.

    DATA(lt_clean_keys) = prepare_keys( it_warehouse_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT wh~WarehouseCode
      FROM zmerp_r_warehouse AS wh
      INNER JOIN @lt_clean_keys AS keys ON wh~WarehouseCode = keys~WarehouseCode
      INTO TABLE @lt_existing_keys.

    LOOP AT lt_clean_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF NOT line_exists( lt_existing_keys[ WarehouseCode = <ls_key>-WarehouseCode ] ).
        INSERT <ls_key> INTO TABLE rt_invalid_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE WarehouseCode IS INITIAL.
    SORT rt_keys BY WarehouseCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING WarehouseCode.
  ENDMETHOD.

ENDCLASS.
