CLASS zcl_merp_md_comp_code_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_comp_code_sel.

  PRIVATE SECTION.
    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_comp_code_sel=>tt_company_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_comp_code_sel=>tt_company_keys.
ENDCLASS.

CLASS zcl_merp_md_comp_code_sel IMPLEMENTATION.

  METHOD zif_merp_md_comp_code_sel~read_company.
    DATA(lt_companies) = zif_merp_md_comp_code_sel~read_companies(
      VALUE #( ( CompanyCode = iv_company_code ) )
    ).

    " An initial code is dropped by prepare_keys, so this one check also covers empty input
    TRY.
        rs_company = lt_companies[ CompanyCode = iv_company_code ].
      CATCH cx_sy_itab_line_not_found.
        RAISE EXCEPTION TYPE zcx_merp_md
          EXPORTING
            textid   = zcx_merp_md=>company_code_not_found
            attr1    = CONV string( iv_company_code )
            severity = if_abap_behv_message=>severity-error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_merp_md_comp_code_sel~read_companies.
    DATA(lt_clean_keys) = prepare_keys( it_company_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT comp~*
      FROM zmerp_r_company_code AS comp
      INNER JOIN @lt_clean_keys AS keys ON comp~CompanyCode = keys~CompanyCode
      INTO TABLE @rt_companies.
  ENDMETHOD.

  METHOD zif_merp_md_comp_code_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_company_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DISTINCT: one row per code and using entity, however many documents use the code
    SELECT DISTINCT usage~CompanyCode, usage~UsedInEntity, usage~IsDocument
      FROM zmerp_i_company_code_usage AS usage
      INNER JOIN @lt_clean_keys AS keys ON usage~CompanyCode = keys~CompanyCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_usages.
  ENDMETHOD.

  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE CompanyCode IS INITIAL.
    SORT rt_keys BY CompanyCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING CompanyCode.
  ENDMETHOD.

ENDCLASS.

