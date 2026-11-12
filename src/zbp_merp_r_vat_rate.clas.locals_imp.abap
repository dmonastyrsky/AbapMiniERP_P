"! Local behavior handler for VAT Rate BO entity.
CLASS lhc_zmerp_r_vat_rate DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_desc TYPE string VALUE 'VALIDATE_DESCRIPTION',
      c_val_perc TYPE string VALUE 'VALIDATE_PERCENTAGE'.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR VatRate
        RESULT result.

    "! VAT codes in use keep their percentage (a new rate needs a new VAT code).
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR VatRate
      RESULT   result.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE VatRate.

    " --- Numbering ---
    "! Assigns early numbers for new VAT Rate entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE VatRate.

    " --- Determinations on modify ---
    "! Interactively checks VAT percentage range during modification.
    METHODS checkPercentageOnModify FOR DETERMINE ON MODIFY
      IMPORTING keys FOR VatRate~checkPercentageOnModify.

    " --- Validations ---
    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR VatRate~validateMandatoryFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages for fields that have been filled in.
    "! Percentage is handled by checkPercentageOnModify (clear and re-check in one place).
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR VatRate~clearMessagesForFilledFields.

ENDCLASS.

CLASS lhc_zmerp_r_vat_rate IMPLEMENTATION.

  " --- Access and state ---
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

  METHOD get_instance_features.
    " Codes used in documents keep their critical fields (one selection for all keys):
    " documents copy the VAT amount, item groups and items only reference the code
    DATA(lt_usages) = NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_usages(
      VALUE #( FOR key IN keys ( VatCode = key-VatCode ) ) ).

    result = VALUE #(
      FOR key IN keys
      ( %tky              = key-%tky
        %field-Percentage = COND #( WHEN line_exists( lt_usages[ VatCode    = key-VatCode
                                                                 IsDocument = abap_true ] )
                                   THEN if_abap_behv=>fc-f-read_only
                                   ELSE if_abap_behv=>fc-f-mandatory ) )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    " Usages of all keys in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_usages(
      VALUE #( FOR key IN keys ( VatCode = key-VatCode ) ) ).

    IF lt_usages IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      IF NOT line_exists( lt_usages[ VatCode = lr_key->VatCode ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky        = lr_key->%tky
        %fail-cause = if_abap_behv=>cause-dependency
      ) TO failed-vatrate.

      " One message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE VatCode = lr_key->VatCode.
        APPEND VALUE #(
          %tky             = lr_key->%tky
          %element-VatCode = if_abap_behv=>mk-on
          %msg             = NEW zcx_merp_md(
                               textid   = zcx_merp_md=>vat_rate_in_use
                               attr1    = CONV #( lr_usage->VatCode )
                               attr2    = CONV #( lr_usage->UsedInEntity )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-vatrate.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  " --- Numbering ---
  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    DATA lx_nro_error TYPE REF TO cx_number_ranges.
    DATA lt_codes     TYPE string_table.

    " Step 1: Count entities requiring key generation using the secondary key
    DATA(lv_needed_count) = REDUCE i( INIT count = 0
                                       FOR entity IN entities USING KEY entity
                                       WHERE ( VatCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_md_codes( is_meta  = zif_merp_constants=>c_vat
                                                             iv_count = lv_needed_count ).
        CATCH cx_number_ranges INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->VatCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            VatCode   = CONV #( <lv_code> )
          ) TO mapped-vatrate.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
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
        " Key already assigned (draft activation passes the draft key): keep it, no new number is drawn
        APPEND VALUE #(
          %cid      = lr_entity->%cid
          %is_draft = lr_entity->%is_draft
          VatCode   = lr_entity->VatCode
        ) TO mapped-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD checkPercentageOnModify.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

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

  " --- Validations ---
  METHOD validateMandatoryFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear the messages of the previous validation run
    reported-vatrate = VALUE #(
      BASE reported-vatrate
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_desc )
      ( %tky        = key-%tky
        %state_area = c_val_perc )
    ).

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

      " 1. Description: mandatory
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

      " 2. Percentage: 0 to 100
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
        " Any error fails the instance
        APPEND VALUE #(
          %tky        = lr_vat->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_vat_rate IN LOCAL MODE
      ENTITY VatRate
      FIELDS ( Description )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vat_rates).

    LOOP AT lt_vat_rates REFERENCE INTO DATA(lr_vat).
      " Clear message area for Description
      IF lr_vat->Description IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_vat->%tky %state_area = c_val_desc ) TO reported-vatrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

