"! Local behavior handler for Item Group BO entity.
CLASS lhc_zmerp_r_item_group DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_desc TYPE string VALUE 'VALIDATE_DESCRIPTION',
      c_val_vat  TYPE string VALUE 'VALIDATE_DEFAULT_VAT'.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR ItemGroup
        RESULT result.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE ItemGroup.

    " --- Numbering ---
    "! Assigns early numbers for new Item Group entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ItemGroup.

    " --- Validations ---
    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR ItemGroup~validateMandatoryFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ItemGroup~clearMessagesForFilledFields.

ENDCLASS.

CLASS lhc_zmerp_r_item_group IMPLEMENTATION.

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

  METHOD precheck_delete.
    " Usages of all keys in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_md_item_group_sel( )->zif_merp_md_item_group_sel~read_usages(
      VALUE #( FOR key IN keys ( ItemGroupCode = key-ItemGroupCode ) ) ).

    IF lt_usages IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      IF NOT line_exists( lt_usages[ ItemGroupCode = lr_key->ItemGroupCode ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky        = lr_key->%tky
        %fail-cause = if_abap_behv=>cause-dependency
      ) TO failed-itemgroup.

      " One message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE ItemGroupCode = lr_key->ItemGroupCode.
        APPEND VALUE #(
          %tky                   = lr_key->%tky
          %element-ItemGroupCode = if_abap_behv=>mk-on
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>item_group_in_use
                                     attr1    = CONV #( lr_usage->ItemGroupCode )
                                     attr2    = CONV #( lr_usage->UsedInEntity )
                                     severity = if_abap_behv_message=>severity-error )
        ) TO reported-itemgroup.
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
                                       WHERE ( ItemGroupCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_md_codes( is_meta  = zif_merp_constants=>c_ig
                                                             iv_count = lv_needed_count ).
        CATCH cx_number_ranges INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->ItemGroupCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          APPEND VALUE #(
            %cid          = lr_entity->%cid
            %is_draft     = lr_entity->%is_draft
            ItemGroupCode = CONV #( <lv_code> )
          ) TO mapped-itemgroup.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-itemgroup.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>item_group_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-itemgroup.
        ENDIF.
      ELSE.
        " Key already assigned (draft activation passes the draft key): keep it, no new number is drawn
        APPEND VALUE #(
          %cid          = lr_entity->%cid
          %is_draft     = lr_entity->%is_draft
          ItemGroupCode = lr_entity->ItemGroupCode
        ) TO mapped-itemgroup.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateMandatoryFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear the messages of the previous validation run
    reported-itemgroup = VALUE #(
      BASE reported-itemgroup
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_desc )
      ( %tky        = key-%tky
        %state_area = c_val_vat )
    ).

    READ ENTITIES OF zmerp_r_item_group IN LOCAL MODE
      ENTITY ItemGroup
      FIELDS ( Description DefaultVatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_groups).

    IF lt_groups IS INITIAL.
      RETURN.
    ENDIF.

    " Read all referenced VAT codes in one selection
    DATA(lt_vat_rates) = NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates(
      VALUE #( FOR grp IN lt_groups ( VatCode = grp-DefaultVatCode ) )
    ).


    LOOP AT lt_groups REFERENCE INTO DATA(lr_group).
      lv_has_error = abap_false.

      " 1. Description: mandatory
      IF lr_group->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_group->%tky
          %state_area          = c_val_desc
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_item_group_description
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ENDIF.

      " 2. Default VAT code: mandatory, exists
      IF lr_group->DefaultVatCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_group->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>select_default_vat_code
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ELSEIF NOT line_exists( lt_vat_rates[ VatCode = lr_group->DefaultVatCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_group->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>vat_code_not_found
                                      attr1    = CONV string( lr_group->DefaultVatCode )
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_group->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-itemgroup.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_item_group IN LOCAL MODE
      ENTITY ItemGroup
      FIELDS ( Description DefaultVatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_groups).

    LOOP AT lt_groups REFERENCE INTO DATA(lr_group).
      " Clear message area for Description
      IF lr_group->Description IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_group->%tky %state_area = c_val_desc ) TO reported-itemgroup.
      ENDIF.

      " Clear message area for Default VAT Code
      IF lr_group->DefaultVatCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_group->%tky %state_area = c_val_vat ) TO reported-itemgroup.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

