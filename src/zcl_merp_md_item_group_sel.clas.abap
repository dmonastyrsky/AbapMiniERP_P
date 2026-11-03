CLASS zcl_merp_md_item_group_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_item_group_sel.

  PRIVATE SECTION.
    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_item_group_sel=>tt_item_group_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_item_group_sel=>tt_item_group_keys.
ENDCLASS.

CLASS zcl_merp_md_item_group_sel IMPLEMENTATION.

  METHOD zif_merp_md_item_group_sel~read_item_group.
    DATA(lt_item_groups) = zif_merp_md_item_group_sel~read_item_groups(
      VALUE #( ( ItemGroupCode = iv_item_group_code ) )
    ).

    " An initial code is dropped by prepare_keys, so this one check also covers empty input
    TRY.
        rs_item_group = lt_item_groups[ ItemGroupCode = iv_item_group_code ].
      CATCH cx_sy_itab_line_not_found.
        RAISE EXCEPTION TYPE zcx_merp_md
          EXPORTING
            textid   = zcx_merp_md=>item_group_not_found
            attr1    = CONV string( iv_item_group_code )
            severity = if_abap_behv_message=>severity-error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_merp_md_item_group_sel~read_item_groups.
    DATA(lt_clean_keys) = prepare_keys( it_item_group_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT grp~*
      FROM zmerp_r_item_group AS grp
      INNER JOIN @lt_clean_keys AS keys ON grp~ItemGroupCode = keys~ItemGroupCode
      INTO TABLE @rt_item_groups.
  ENDMETHOD.

  METHOD zif_merp_md_item_group_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_item_group_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DISTINCT: one row per code and using entity, however many documents use the code
    SELECT DISTINCT usage~ItemGroupCode, usage~UsedInEntity, usage~IsDocument
      FROM zmerp_i_item_group_usage AS usage
      INNER JOIN @lt_clean_keys AS keys ON usage~ItemGroupCode = keys~ItemGroupCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_usages.
  ENDMETHOD.

  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE ItemGroupCode IS INITIAL.
    SORT rt_keys BY ItemGroupCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING ItemGroupCode.
  ENDMETHOD.

ENDCLASS.

