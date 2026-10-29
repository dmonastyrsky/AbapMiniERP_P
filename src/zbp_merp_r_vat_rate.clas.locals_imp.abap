"! Local behavior handler for VAT Rate BO entity.
CLASS lhc_zmerp_r_vat_rate DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_desc TYPE string VALUE 'VALIDATE_DESCRIPTION',
      c_val_perc TYPE string VALUE 'VALIDATE_PERCENTAGE'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR VatRate
        RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR VatRate~validateMandatoryFields.

    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR VatRate~clearMessagesForFilledFields.

    "! Interactively checks VAT percentage range during modification.
    METHODS checkPercentageOnModify FOR DETERMINE ON MODIFY
      IMPORTING keys FOR VatRate~checkPercentageOnModify.

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

    " Clear previous validation messages for individual state areas to prevent duplicate errors in UI
    reported-vatrate = VALUE #(
      BASE reported-vatrate
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_desc )
      ( %tky        = key-%tky
        %state_area = c_val_perc )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_vat_rate IN LOCAL MODE
      ENTITY VatRate
      FIELDS ( Description Percentage )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vat_rates).

    IF lt_vat_rates IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_vat_rates REFERENCE INTO DATA(lr_vat).
      lv_has_error = abap_false.

      " 1. VAT Rate Description Mandatory Validation
      IF lr_vat->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_vat->%tky
          %state_area          = c_val_desc
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_vat_description
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-vatrate.
      ENDIF.

      " 2. VAT Percentage Mandatory & Business Range Validation
      IF zcl_merp_md_validator=>is_vat_percentage_valid( lr_vat->Percentage ) = abap_false.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                = lr_vat->%tky
          %state_area         = c_val_perc
          %msg                = NEW zcx_merp_md(
                                  textid   = zcx_merp_md=>invalid_vat_percentage
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

  METHOD checkPercentageOnModify.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " Read current percentage value from draft instance
    READ ENTITIES OF zmerp_r_vat_rate IN LOCAL MODE
      ENTITY VatRate
      FIELDS ( Percentage )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vat_rates).

    IF lt_vat_rates IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_vat_rates REFERENCE INTO DATA(lr_vat).
      " Always clear the previous validation message for this field state area
      APPEND VALUE #( %tky = lr_vat->%tky %state_area = c_val_perc ) TO reported-vatrate.

      IF zcl_merp_md_validator=>is_vat_percentage_valid( lr_vat->Percentage ) = abap_false.
        APPEND VALUE #(
          %tky                = lr_vat->%tky
          %state_area         = c_val_perc
          %msg                = NEW zcx_merp_md(
                                  textid   = zcx_merp_md=>invalid_vat_percentage
                                  severity = if_abap_behv_message=>severity-error )
          %element-Percentage = if_abap_behv=>mk-on
        ) TO reported-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " Read entity state in local mode
    READ ENTITIES OF zmerp_r_vat_rate IN LOCAL MODE
      ENTITY VatRate
      FIELDS ( Description Percentage )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vat_rates).

    LOOP AT lt_vat_rates REFERENCE INTO DATA(lr_vat).
      " Clear message area for Description
      IF lr_vat->Description IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_vat->%tky %state_area = c_val_desc ) TO reported-vatrate.
      ENDIF.

      " Clear message area for Percentage if value is within valid range via global validator
      IF zcl_merp_md_validator=>is_vat_percentage_valid( lr_vat->Percentage ) = abap_true.
        APPEND VALUE #( %tky = lr_vat->%tky %state_area = c_val_perc ) TO reported-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    DATA lx_nro_error TYPE REF TO cx_root.
    DATA lt_codes     TYPE string_table.

    " Step 1: Count entities requiring key generation using the secondary key
    DATA(lv_needed_count) = REDUCE i( INIT count = 0
                                       FOR entity IN entities USING KEY entity
                                       WHERE ( VatCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_vat_codes_nro( iv_count = lv_needed_count ).
        CATCH cx_number_ranges cx_root INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->VatCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          " Map successfully generated key
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            VatCode   = CONV #( <lv_code> )
          ) TO mapped-vatrate.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          " Mark entity failure
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-vatrate.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>vat_rate_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-vatrate.
        ENDIF.
      ELSE.
        " Retain explicitly provided code without affecting lt_codes indexing
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
          %msg             = NEW zcx_merp_md(
                                  textid   = zcx_merp_md=>vat_rate_in_use
                                  attr1    = CONV #( lr_dep->vatcode )
                                  attr2    = CONV #( lr_dep->usedinentity )
                                  severity = if_abap_behv_message=>severity-error )
        ) TO reported-vatrate.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
