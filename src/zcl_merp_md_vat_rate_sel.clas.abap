CLASS zcl_merp_md_vat_rate_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_vat_rate_sel.

  PRIVATE SECTION.
    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys.
ENDCLASS.

CLASS zcl_merp_md_vat_rate_sel IMPLEMENTATION.

  METHOD zif_merp_md_vat_rate_sel~read_vat_rate.
    DATA(lt_vat_rates) = zif_merp_md_vat_rate_sel~read_vat_rates(
      VALUE #( ( VatCode = iv_vat_code ) )
    ).

    " An initial code is dropped by prepare_keys, so this one check also covers empty input
    TRY.
        rs_vat_rate = lt_vat_rates[ VatCode = iv_vat_code ].
      CATCH cx_sy_itab_line_not_found.
        RAISE EXCEPTION TYPE zcx_merp_md
          EXPORTING
            textid   = zcx_merp_md=>vat_code_not_found
            attr1    = CONV string( iv_vat_code )
            severity = if_abap_behv_message=>severity-error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_merp_md_vat_rate_sel~read_vat_rates.
    DATA(lt_clean_keys) = prepare_keys( it_vat_rate_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT vat~*
      FROM zmerp_r_vat_rate AS vat
      INNER JOIN @lt_clean_keys AS keys ON vat~VatCode = keys~VatCode
      INTO TABLE @rt_vat_rates.
  ENDMETHOD.

  METHOD zif_merp_md_vat_rate_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_vat_rate_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DISTINCT: one row per code and using entity, however many documents use the code
    SELECT DISTINCT usage~VatCode, usage~UsedInEntity, usage~IsDocument
      FROM zmerp_i_vat_rate_usage AS usage
      INNER JOIN @lt_clean_keys AS keys ON usage~VatCode = keys~VatCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_usages.
  ENDMETHOD.

  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE VatCode IS INITIAL.
    SORT rt_keys BY VatCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING VatCode.
  ENDMETHOD.

ENDCLASS.
