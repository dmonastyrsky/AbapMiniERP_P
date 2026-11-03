CLASS zcl_merp_md_bus_partner_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_md_bus_partner_sel.

  PRIVATE SECTION.
    "! Cleanses, sorts and removes duplicates from input keys
    "! @parameter it_keys | Raw table of keys
    "! @parameter rt_keys | Processed clean table of keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_md_bus_partner_sel=>tt_partner_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_md_bus_partner_sel=>tt_partner_keys.
ENDCLASS.

CLASS zcl_merp_md_bus_partner_sel IMPLEMENTATION.

  METHOD zif_merp_md_bus_partner_sel~read_partner.
    DATA(lt_partners) = zif_merp_md_bus_partner_sel~read_partners(
      VALUE #( ( PartnerCode = iv_partner_code ) )
    ).

    " An initial code is dropped by prepare_keys, so this one check also covers empty input
    TRY.
        rs_partner = lt_partners[ PartnerCode = iv_partner_code ].
      CATCH cx_sy_itab_line_not_found.
        RAISE EXCEPTION TYPE zcx_merp_md
          EXPORTING
            textid   = zcx_merp_md=>business_partner_not_found
            attr1    = CONV string( iv_partner_code )
            severity = if_abap_behv_message=>severity-error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_merp_md_bus_partner_sel~read_partners.
    DATA(lt_clean_keys) = prepare_keys( it_partner_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT bp~*
      FROM zmerp_r_bus_partner AS bp
      INNER JOIN @lt_clean_keys AS keys ON bp~PartnerCode = keys~PartnerCode
      INTO TABLE @rt_partners.
  ENDMETHOD.

  METHOD zif_merp_md_bus_partner_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_partner_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DISTINCT: one row per code and using entity, however many documents use the code
    SELECT DISTINCT usage~PartnerCode, usage~UsedInEntity, usage~UsedAsSupplier, usage~UsedAsCustomer, usage~IsDocument
      FROM zmerp_i_bus_partner_usage AS usage
      INNER JOIN @lt_clean_keys AS keys ON usage~PartnerCode = keys~PartnerCode
      INTO CORRESPONDING FIELDS OF TABLE @rt_usages.
  ENDMETHOD.

  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE PartnerCode IS INITIAL.
    SORT rt_keys BY PartnerCode.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING PartnerCode.
  ENDMETHOD.

ENDCLASS.

