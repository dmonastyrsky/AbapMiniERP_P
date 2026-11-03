CLASS zcl_merp_md_item_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_item_sel.

  PRIVATE SECTION.
    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_item_sel=>tt_item_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_item_sel=>tt_item_keys.
ENDCLASS.

CLASS zcl_merp_md_item_sel IMPLEMENTATION.

  METHOD zif_merp_md_item_sel~read_item.
    DATA(lt_items) = zif_merp_md_item_sel~read_items(
      VALUE #( ( ItemCode = iv_item_code ) )
    ).

    " An initial code is dropped by prepare_keys, so this one check also covers empty input
    TRY.
        rs_item = lt_items[ ItemCode = iv_item_code ].
      CATCH cx_sy_itab_line_not_found.
        RAISE EXCEPTION TYPE zcx_merp_md
          EXPORTING
            textid   = zcx_merp_md=>item_not_found
            attr1    = CONV string( iv_item_code )
            severity = if_abap_behv_message=>severity-error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_merp_md_item_sel~read_items.
    DATA(lt_clean_keys) = prepare_keys( it_item_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT item~*
      FROM zmerp_r_item AS item
      INNER JOIN @lt_clean_keys AS keys ON item~ItemCode = keys~ItemCode
      INTO TABLE @rt_items.
  ENDMETHOD.

  METHOD zif_merp_md_item_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_item_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DISTINCT: one row per code and using entity, however many documents use the code
    SELECT DISTINCT usage~ItemCode, usage~UsedInEntity, usage~IsDocument
      FROM zmerp_i_item_usage AS usage
      INNER JOIN @lt_clean_keys AS keys ON usage~ItemCode = keys~ItemCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_usages.
  ENDMETHOD.

  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE ItemCode IS INITIAL.
    SORT rt_keys BY ItemCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING ItemCode.
  ENDMETHOD.

ENDCLASS.

