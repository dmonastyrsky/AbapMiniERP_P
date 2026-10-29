CLASS zcl_merp_md_item_group_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_item_group_sel.

  PRIVATE SECTION.
    TYPES tt_item_group_keys_unique TYPE HASHED TABLE OF zif_merp_md_item_group_sel=>ty_item_group_key
                                       WITH UNIQUE KEY ItemGroupCode.

    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_item_group_sel=>tt_item_group_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_item_group_sel=>tt_item_group_keys.
ENDCLASS.

CLASS zcl_merp_md_item_group_sel IMPLEMENTATION.

  METHOD zif_merp_md_item_group_sel~read_item_group.
    IF iv_item_group_code IS INITIAL.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>item_group_not_found
          attr1    = CONV string( iv_item_group_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.

    DATA(lt_item_groups) = zif_merp_md_item_group_sel~read_item_groups(
      VALUE #( ( ItemGroupCode = iv_item_group_code ) )
    ).

    ASSIGN lt_item_groups[ ItemGroupCode = iv_item_group_code ] TO FIELD-SYMBOL(<ls_detail>).
    IF sy-subrc = 0.
      rs_item_group = <ls_detail>.
    ELSE.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>item_group_not_found
          attr1    = CONV string( iv_item_group_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.
  ENDMETHOD.


  METHOD zif_merp_md_item_group_sel~read_item_groups.
    DATA(lt_clean_keys) = prepare_keys( it_item_group_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT grp~ItemGroupCode,
           grp~Description,
           grp~DefaultVatCode,
           grp~IsBlocked,
           grp~CreatedBy,
           grp~CreatedAt,
           grp~LocalLastChangedBy,
           grp~LocalLastChangedAt,
           grp~LastChangedAt
      FROM zmerp_r_item_group AS grp
      INNER JOIN @lt_clean_keys AS keys ON grp~ItemGroupCode = keys~ItemGroupCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_item_groups.
  ENDMETHOD.


  METHOD zif_merp_md_item_group_sel~validate_item_groups.
    DATA lt_existing_keys TYPE tt_item_group_keys_unique.

    DATA(lt_clean_keys) = prepare_keys( it_item_group_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT grp~ItemGroupCode
      FROM zmerp_r_item_group AS grp
      INNER JOIN @lt_clean_keys AS keys ON grp~ItemGroupCode = keys~ItemGroupCode
      INTO TABLE @lt_existing_keys.

    LOOP AT lt_clean_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF NOT line_exists( lt_existing_keys[ ItemGroupCode = <ls_key>-ItemGroupCode ] ).
        INSERT <ls_key> INTO TABLE rt_invalid_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE ItemGroupCode IS INITIAL.
    SORT rt_keys BY ItemGroupCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING ItemGroupCode.
  ENDMETHOD.

ENDCLASS.
