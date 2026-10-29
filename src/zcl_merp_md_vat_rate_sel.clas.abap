CLASS zcl_merp_md_vat_rate_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_vat_rate_sel.

  PRIVATE SECTION.
    TYPES tt_vat_rate_keys_unique TYPE HASHED TABLE OF zif_merp_md_vat_rate_sel=>ty_vat_rate_key
                                       WITH UNIQUE KEY VatCode.

    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys.
ENDCLASS.


CLASS zcl_merp_md_vat_rate_sel IMPLEMENTATION.

  METHOD zif_merp_md_vat_rate_sel~read_vat_rate.
    IF iv_vat_code IS INITIAL.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>vat_code_not_found
          attr1    = CONV string( iv_vat_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.

    DATA(lt_vat_rates) = zif_merp_md_vat_rate_sel~read_vat_rates(
      VALUE #( ( VatCode = iv_vat_code ) )
    ).

    ASSIGN lt_vat_rates[ VatCode = iv_vat_code ] TO FIELD-SYMBOL(<ls_detail>).
    IF sy-subrc = 0.
      rs_vat_rate = <ls_detail>.
    ELSE.
      RAISE EXCEPTION TYPE zcx_merp_md
        EXPORTING
          textid   = zcx_merp_md=>vat_code_not_found
          attr1    = CONV string( iv_vat_code )
          severity = if_abap_behv_message=>severity-error.
    ENDIF.
  ENDMETHOD.


  METHOD zif_merp_md_vat_rate_sel~read_vat_rates.
    DATA(lt_clean_keys) = prepare_keys( it_vat_rate_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT vat~VatCode,
           vat~Description,
           vat~Percentage,
           vat~IsBlocked,
           vat~CreatedBy,
           vat~CreatedAt,
           vat~LocalLastChangedBy,
           vat~LocalLastChangedAt,
           vat~LastChangedAt
      FROM zmerp_r_vat_rate AS vat
      INNER JOIN @lt_clean_keys AS keys ON vat~VatCode = keys~VatCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_vat_rates.
  ENDMETHOD.


  METHOD zif_merp_md_vat_rate_sel~validate_vat_rates.
    DATA lt_existing_keys TYPE tt_vat_rate_keys_unique.

    DATA(lt_clean_keys) = prepare_keys( it_vat_rate_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT vat~VatCode
      FROM zmerp_r_vat_rate AS vat
      INNER JOIN @lt_clean_keys AS keys ON vat~VatCode = keys~VatCode
      INTO TABLE @lt_existing_keys.

    LOOP AT lt_clean_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF NOT line_exists( lt_existing_keys[ VatCode = <ls_key>-VatCode ] ).
        INSERT <ls_key> INTO TABLE rt_invalid_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE VatCode IS INITIAL.
    SORT rt_keys BY VatCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING VatCode.
  ENDMETHOD.

ENDCLASS.
