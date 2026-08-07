"! Local behavior handler for VAT Rate BO entity.
CLASS lhc_zmerp_r_vat_rate DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_state_area_mandatory  TYPE string VALUE 'VALIDATE_MANDATORY',
      c_state_area_percentage TYPE string VALUE 'VALIDATE_PERCENTAGE'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR VatRate
        RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR VatRate~validateMandatoryFields.

    "! Validates VAT percentage range.
    METHODS validatePercentage FOR VALIDATE ON SAVE
      IMPORTING keys FOR VatRate~validatePercentage.

    "! Assigns early numbers for new VAT Rate entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE VatRate.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE VatRate.
ENDCLASS.

CLASS lhc_zmerp_r_vat_rate IMPLEMENTATION.

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
    reported-vatrate = VALUE #(
      BASE reported-vatrate
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_state_area_mandatory )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_vat_rate IN LOCAL MODE
      ENTITY VatRate
      FIELDS ( Description )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vat_rates).

    IF lt_vat_rates IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_vat_rates REFERENCE INTO DATA(lr_vat).
      lv_has_error = abap_false.

      IF lr_vat->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_vat->%tky
          %state_area          = c_state_area_mandatory
          %msg                 = NEW zcm_merp_messages(
                                   textid   = zcm_merp_messages=>enter_vat_name
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-vatrate.
      ENDIF.

      IF lv_has_error = abap_true.
        " Mark entity instance as failed to prevent transaction commit
        APPEND VALUE #(
          %tky        = lr_vat->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatePercentage.
    DATA lv_has_error TYPE abap_bool.

    " Clear previous validation messages for this state area to prevent duplicate errors in UI
    reported-vatrate = VALUE #(
      BASE reported-vatrate
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_state_area_percentage )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_vat_rate IN LOCAL MODE
      ENTITY VatRate
      FIELDS ( Percentage )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vat_rates).

    IF lt_vat_rates IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_vat_rates REFERENCE INTO DATA(lr_vat).
      lv_has_error = abap_false.

      IF lr_vat->Percentage < 0 OR lr_vat->Percentage > 100.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                = lr_vat->%tky
          %state_area         = c_state_area_percentage
          %msg                = NEW zcm_merp_messages(
                                  textid   = zcm_merp_messages=>invalid_vat_percentage
                                  severity = if_abap_behv_message=>severity-error )
          %element-Percentage = if_abap_behv=>mk-on
        ) TO reported-vatrate.
      ENDIF.

      IF lv_has_error = abap_true.
        " Mark entity instance as failed to prevent transaction commit
        APPEND VALUE #(
          %tky        = lr_vat->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->VatCode IS INITIAL.

        DATA(lv_next_vat_code) = VALUE string( ).

        TRY.
            lv_next_vat_code = zcl_merp_num_range_util=>get_next_vat_code_nro( ).
          CATCH cx_number_ranges.
            CLEAR lv_next_vat_code.
        ENDTRY.

        IF lv_next_vat_code IS NOT INITIAL.
          " Map generated business key to the draft/content creation ID (%cid)
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            VatCode   = lv_next_vat_code
          ) TO mapped-vatrate.
        ELSE.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-vatrate.

          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcm_merp_messages(
                          textid   = zcm_merp_messages=>vat_number_failed
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-vatrate.
        ENDIF.
      ELSE.
        " Preserve user-provided key if supplied during creation
        APPEND VALUE #(
          %cid      = lr_entity->%cid
          %is_draft = lr_entity->%is_draft
          VatCode   = lr_entity->VatCode
        ) TO mapped-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             vatcode TYPE zmerp_vat_code,
           END OF ty_key.

    TYPES: BEGIN OF ty_dependency,
             vatcode      TYPE zmerp_vat_code,
             usedinentity TYPE zmerp_entity_name,
           END OF ty_dependency.

    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH NON-UNIQUE KEY vatcode.
    DATA lt_dependencies TYPE SORTED TABLE OF ty_dependency WITH NON-UNIQUE KEY vatcode.
    DATA lv_failed_added TYPE abap_bool.

    " Collect key values and remove potential duplicates to optimize SQL predicate standard
    lt_keys = VALUE #( FOR key IN keys WHERE ( VatCode IS NOT INITIAL ) ( vatcode = key-VatCode ) ).
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING vatcode.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk check database dependencies for collected key set
    SELECT DISTINCT
           usage~VatCode      AS vatcode,
           usage~UsedInEntity AS usedinentity
      FROM zmerp_i_vat_rate_usage AS usage
      INNER JOIN @lt_keys AS key ON usage~VatCode = key~vatcode
      INTO TABLE @lt_dependencies.

    IF lt_dependencies IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      lv_failed_added = abap_false.

      " ABAP runtime automatically performs a highly efficient binary boundary scan here
      LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep)
        WHERE vatcode = lr_key->VatCode.

        " Record entity failure state ONCE per key
        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_key->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-vatrate.
          lv_failed_added = abap_true.
        ENDIF.

        " Report explicit dependency error message to UI
        APPEND VALUE #(
          %tky             = lr_key->%tky
          %element-VatCode = if_abap_behv=>mk-on
          %msg             = NEW zcm_merp_messages(
                                  textid   = zcm_merp_messages=>vat_rate_in_use
                                  attr1    = CONV #( lr_dep->vatcode )
                                  attr2    = CONV #( lr_dep->usedinentity )
                                  severity = if_abap_behv_message=>severity-error )
        ) TO reported-vatrate.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
