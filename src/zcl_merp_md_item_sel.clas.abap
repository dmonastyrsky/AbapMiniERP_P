CLASS zcl_merp_md_item_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_item_sel.

  PRIVATE SECTION.
    TYPES tt_item_keys_unique TYPE HASHED TABLE OF zif_merp_md_item_sel=>ty_item_key
                                   WITH UNIQUE KEY ItemCode.

    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_item_sel=>tt_item_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_item_sel=>tt_item_keys.
ENDCLASS.


CLASS zcl_merp_md_item_sel IMPLEMENTATION.

  METHOD zif_merp_md_item_sel~read_item.
    IF iv_item_code IS INITIAL.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>item_not_found
          attr1    = CONV string( iv_item_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.

    DATA(lt_items) = zif_merp_md_item_sel~read_items(
      VALUE #( ( ItemCode = iv_item_code ) )
    ).

    ASSIGN lt_items[ ItemCode = iv_item_code ] TO FIELD-SYMBOL(<ls_detail>).
    IF sy-subrc = 0.
      rs_item = <ls_detail>.
    ELSE.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>item_not_found
          attr1    = CONV string( iv_item_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.
  ENDMETHOD.

  METHOD zif_merp_md_item_sel~read_items.
    DATA(lt_clean_keys) = prepare_keys( it_item_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT item~ItemCode,
           item~Description,
           item~Article,
           item~ItemTypeCode,
           item~ItemGroupCode,
           item~DefaultVatCode,
           item~BaseUnitOfMeasure,
           item~IsBlocked,
           item~CreatedBy,
           item~CreatedAt,
           item~LocalLastChangedBy,
           item~LocalLastChangedAt,
           item~LastChangedAt
      FROM zmerp_r_item AS item
      INNER JOIN @lt_clean_keys AS keys ON item~ItemCode = keys~ItemCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_items.
  ENDMETHOD.


  METHOD zif_merp_md_item_sel~validate_items.
    DATA lt_existing_keys TYPE tt_item_keys_unique.

    DATA(lt_clean_keys) = prepare_keys( it_item_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT item~ItemCode
      FROM zmerp_r_item AS item
      INNER JOIN @lt_clean_keys AS keys ON item~ItemCode = keys~ItemCode
      INTO TABLE @lt_existing_keys.

    LOOP AT lt_clean_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF NOT line_exists( lt_existing_keys[ ItemCode = <ls_key>-ItemCode ] ).
        INSERT <ls_key> INTO TABLE rt_invalid_keys.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE ItemCode IS INITIAL.
    SORT rt_keys BY ItemCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING ItemCode.
  ENDMETHOD.

ENDCLASS.
