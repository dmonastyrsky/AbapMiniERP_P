"! Local behavior handler for Company Code BO entity.
CLASS lhc_zmerp_r_company_code DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_state_area_mandatory TYPE string VALUE 'VALIDATE_MANDATORY'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR CompanyCode
        RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR CompanyCode~validateMandatoryFields.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE CompanyCode.

    "! Formats inputs on modification.
    METHODS formatFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CompanyCode~formatFields.

ENDCLASS.

CLASS lhc_zmerp_r_company_code IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD validateMandatoryFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear previous validation messages for this state area to prevent duplicate errors in UI
    reported-companycode = VALUE #(
      BASE reported-companycode
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_state_area_mandatory )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_company_code IN LOCAL MODE
      ENTITY CompanyCode
      FIELDS ( CompanyName CompanyPrefix CurrencyCode Country )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_comp_codes).

    IF lt_comp_codes IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_comp_codes REFERENCE INTO DATA(lr_comp_code).
      lv_has_error = abap_false.

      IF lr_comp_code->CompanyName IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_comp_code->%tky
          %state_area          = c_state_area_mandatory
          %msg                 = NEW zcm_merp_messages(
                                   textid   = zcm_merp_messages=>enter_company_name
                                   severity = if_abap_behv_message=>severity-error )
          %element-CompanyName = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ENDIF.

      IF lr_comp_code->CompanyPrefix IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_comp_code->%tky
          %state_area            = c_state_area_mandatory
          %msg                   = NEW zcm_merp_messages(
                                     textid   = zcm_merp_messages=>enter_company_prefix
                                     severity = if_abap_behv_message=>severity-error )
          %element-CompanyPrefix = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ENDIF.

      IF lr_comp_code->CurrencyCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_comp_code->%tky
          %state_area           = c_state_area_mandatory
          %msg                  = NEW zcm_merp_messages(
                                    textid   = zcm_merp_messages=>enter_currency
                                    severity = if_abap_behv_message=>severity-error )
          %element-CurrencyCode = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ENDIF.

      IF lr_comp_code->Country IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky              = lr_comp_code->%tky
          %state_area       = c_state_area_mandatory
          %msg              = NEW zcm_merp_messages(
                                textid   = zcm_merp_messages=>enter_country
                                severity = if_abap_behv_message=>severity-error )
          %element-Country  = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ENDIF.

      IF lv_has_error = abap_true.
        " Mark entity instance as failed to prevent transaction commit
        APPEND VALUE #(
          %tky        = lr_comp_code->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-companycode.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD formatFields.

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_company_code IN LOCAL MODE
      ENTITY CompanyCode
      FIELDS ( CompanyPrefix )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_comp_codes).

    IF lt_comp_codes IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_update TYPE TABLE FOR UPDATE zmerp_r_company_code.

    LOOP AT lt_comp_codes REFERENCE INTO DATA(lr_comp_code).
      IF lr_comp_code->CompanyPrefix IS NOT INITIAL.
        DATA(lv_format_prefix) = to_upper( lr_comp_code->CompanyPrefix ).

        IF lr_comp_code->CompanyPrefix <> lv_format_prefix.
          APPEND VALUE #(
            %tky                  = lr_comp_code->%tky
            CompanyPrefix         = lv_format_prefix
            %control-CompanyPrefix = if_abap_behv=>mk-on
          ) TO lt_update.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_company_code IN LOCAL MODE
        ENTITY CompanyCode
        UPDATE FIELDS ( CompanyPrefix )
        WITH lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             companycode TYPE zmerp_company_code,
           END OF ty_key.

    TYPES: BEGIN OF ty_dependency,
             companycode  TYPE zmerp_company_code,
             usedinentity TYPE zmerp_entity_name,
           END OF ty_dependency.

    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH NON-UNIQUE KEY companycode.
    DATA lt_dependencies TYPE SORTED TABLE OF ty_dependency WITH NON-UNIQUE KEY companycode.
    DATA lv_failed_added TYPE abap_bool.

    " Collect key values and remove potential duplicates to optimize SQL predicate standard
    lt_keys = VALUE #( FOR key IN keys WHERE ( CompanyCode IS NOT INITIAL ) ( companycode = key-CompanyCode ) ).
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING companycode.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk check database dependencies for collected key set
    SELECT DISTINCT
           usage~CompanyCode  AS companycode,
           usage~UsedInEntity AS usedinentity
      FROM zmerp_i_company_code_usage AS usage
      INNER JOIN @lt_keys AS key ON usage~CompanyCode = key~companycode
      INTO TABLE @lt_dependencies.

    IF lt_dependencies IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      lv_failed_added = abap_false.

      " ABAP runtime automatically performs a highly efficient binary boundary scan here
      LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep)
        WHERE companycode = lr_key->CompanyCode.

        " Record entity failure state ONCE per key
        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_key->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-companycode.
          lv_failed_added = abap_true.
        ENDIF.

        " Report explicit dependency error message to UI
        APPEND VALUE #(
          %tky                 = lr_key->%tky
          %element-CompanyCode = if_abap_behv=>mk-on
          %msg                  = NEW zcm_merp_messages(
                                      textid   = zcm_merp_messages=>company_code_in_use
                                      attr1    = CONV #( lr_dep->companycode )
                                      attr2    = CONV #( lr_dep->usedinentity )
                                      severity = if_abap_behv_message=>severity-error )
        ) TO reported-companycode.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

*  METHOD precheck_delete.
*    IF keys IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    DATA lv_failed_added TYPE abap_bool.
*
*    DATA(lt_key_strings) = VALUE string_table(
*      FOR key IN keys ( CONV string( key-CompanyCode ) )
*    ).
*
*    DATA(lt_blocked) = zcl_merp_md_util=>check_dependencies(
*      it_keys           = lt_key_strings
*      iv_usage_cds      = 'ZMERP_I_COMPANY_CODE_USAGE'
*      iv_key_field_name = 'COMPANYCODE'
*      is_textid         = zcm_merp_messages=>company_code_in_use
*    ).
*
*    IF lt_blocked IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    LOOP AT keys REFERENCE INTO DATA(lr_key).
*      lv_failed_added = abap_false.
*
*      LOOP AT lt_blocked REFERENCE INTO DATA(lr_blocked)
*        WHERE key_value = lr_key->CompanyCode.
*
*        IF lv_failed_added = abap_false.
*          APPEND VALUE #(
*            %tky        = lr_key->%tky
*            %fail-cause = if_abap_behv=>cause-dependency
*          ) TO failed-companycode.
*          lv_failed_added = abap_true.
*        ENDIF.
*
*        IF lr_blocked->msg IS BOUND.
*          APPEND VALUE #(
*            %tky                 = lr_key->%tky
*            %element-CompanyCode = if_abap_behv=>mk-on
*            %msg                 = lr_blocked->msg
*          ) TO reported-companycode.
*        ENDIF.
*      ENDLOOP.
*    ENDLOOP.
*  ENDMETHOD.

ENDCLASS.
