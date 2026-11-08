"! Local behavior handler for Item BO entity.
CLASS lhc_zmerp_r_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_desc  TYPE string VALUE 'VALIDATE_DESCRIPTION',
      c_val_type  TYPE string VALUE 'VALIDATE_ITEM_TYPE',
      c_val_group TYPE string VALUE 'VALIDATE_ITEM_GROUP',
      c_val_vat   TYPE string VALUE 'VALIDATE_DEFAULT_VAT',
      c_val_uom   TYPE string VALUE 'VALIDATE_BASE_UOM'.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
      REQUEST requested_authorizations FOR Item
      RESULT result.

    "! Items used in documents keep their type and base unit (stock is kept per item and unit).
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR Item
      RESULT   result.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Item.

    " --- Numbering ---
    "! Assigns early numbers for new Item entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Item.

    " --- Determinations on modify ---
    "! Automatically sets Default VAT Code based on the selected Item Group.
    METHODS setDefaultVatCode FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setDefaultVatCode.

    " --- Validations ---
    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateMandatoryFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~clearMessagesForFilledFields.

ENDCLASS.

CLASS lhc_zmerp_r_item IMPLEMENTATION.

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
    " Codes in use keep their critical fields (one selection for all keys)
    DATA(lt_usages) = NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_usages(
      VALUE #( FOR key IN keys ( ItemCode = key-ItemCode ) ) ).

    result = VALUE #(
      FOR key IN keys
      LET lv_control = COND #( WHEN line_exists( lt_usages[ ItemCode = key-ItemCode ] )
                               THEN if_abap_behv=>fc-f-read_only
                               ELSE if_abap_behv=>fc-f-mandatory ) IN
      ( %tky                     = key-%tky
        %field-ItemTypeCode      = lv_control
        %field-BaseUnitOfMeasure = lv_control )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    " Usages of all keys in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_usages(
      VALUE #( FOR key IN keys ( ItemCode = key-ItemCode ) ) ).

    IF lt_usages IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      IF NOT line_exists( lt_usages[ ItemCode = lr_key->ItemCode ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky        = lr_key->%tky
        %fail-cause = if_abap_behv=>cause-dependency
      ) TO failed-item.

      " One message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE ItemCode = lr_key->ItemCode.
        APPEND VALUE #(
          %tky              = lr_key->%tky
          %element-ItemCode = if_abap_behv=>mk-on
          %msg              = NEW zcx_merp_md(
                                textid   = zcx_merp_md=>item_in_use
                                attr1    = CONV #( lr_usage->ItemCode )
                                attr2    = CONV #( lr_usage->UsedInEntity )
                                severity = if_abap_behv_message=>severity-error )
        ) TO reported-item.
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
                                       WHERE ( ItemCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_item_codes_nro( iv_count = lv_needed_count ).
        CATCH cx_number_ranges INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->ItemCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            ItemCode  = CONV #( <lv_code> )
          ) TO mapped-item.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-item.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>item_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-item.
        ENDIF.
      ELSE.
        " Key already assigned (draft activation passes the draft key): keep it, no new number is drawn
        APPEND VALUE #(
          %cid      = lr_entity->%cid
          %is_draft = lr_entity->%is_draft
          ItemCode  = lr_entity->ItemCode
        ) TO mapped-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD setDefaultVatCode.
    READ ENTITIES OF zmerp_r_item IN LOCAL MODE
      ENTITY Item
      FIELDS ( ItemGroupCode DefaultVatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Read all referenced item groups in one selection
    DATA(lt_item_groups) = NEW zcl_merp_md_item_group_sel( )->zif_merp_md_item_group_sel~read_item_groups(
      VALUE #( FOR item IN lt_items ( ItemGroupCode = item-ItemGroupCode ) )
    ).

    IF lt_item_groups IS INITIAL.
      RETURN.
    ENDIF.

    " Read the default VAT codes of these groups: a blocked (obsolete) VAT code is not proposed
    DATA(lt_vat_rates) = NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates(
      VALUE #( FOR group IN lt_item_groups ( VatCode = group-DefaultVatCode ) )
    ).

    DATA lt_update TYPE TABLE FOR UPDATE zmerp_r_item.

    " Item VAT code = group VAT code if it is current, otherwise empty
    LOOP AT lt_items REFERENCE INTO DATA(lr_item) WHERE ItemGroupCode IS NOT INITIAL.
      ASSIGN lt_item_groups[ ItemGroupCode = lr_item->ItemGroupCode ] TO FIELD-SYMBOL(<ls_item_group>).

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_vat_code) = COND zmerp_vat_code( WHEN line_exists( lt_vat_rates[ VatCode   = <ls_item_group>-DefaultVatCode
                                                                               IsBlocked = abap_false ] )
                                               THEN <ls_item_group>-DefaultVatCode ).

      IF lr_item->DefaultVatCode <> lv_vat_code.
        APPEND VALUE #( %tky = lr_item->%tky DefaultVatCode = lv_vat_code ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_item IN LOCAL MODE
        ENTITY Item
        UPDATE FIELDS ( DefaultVatCode )
        WITH lt_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateMandatoryFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear the messages of the previous validation run
    reported-item = VALUE #(
      BASE reported-item
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_desc )
      ( %tky        = key-%tky
        %state_area = c_val_type )
      ( %tky        = key-%tky
        %state_area = c_val_group )
      ( %tky        = key-%tky
        %state_area = c_val_vat )
      ( %tky        = key-%tky
        %state_area = c_val_uom )
    ).

    READ ENTITIES OF zmerp_r_item IN LOCAL MODE
      ENTITY Item
      FIELDS ( Description ItemTypeCode ItemGroupCode DefaultVatCode BaseUnitOfMeasure )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky ) )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Read all referenced item groups, VAT codes and units (one selection each)
    DATA(lt_item_groups) = NEW zcl_merp_md_item_group_sel( )->zif_merp_md_item_group_sel~read_item_groups(
      VALUE #( FOR item IN lt_items ( ItemGroupCode = item-ItemGroupCode ) )
    ).

    DATA(lt_vat_rates) = NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates(
      VALUE #( FOR item IN lt_items ( VatCode = item-DefaultVatCode ) )
    ).

    DATA(lt_units) = NEW zcl_merp_md_sap_sel( )->zif_merp_md_sap_sel~read_units(
      VALUE #( FOR item IN lt_items ( UnitOfMeasure = item-BaseUnitOfMeasure ) )
    ).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      lv_has_error = abap_false.

      " 1. Description: mandatory
      IF lr_item->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_item->%tky
          %state_area          = c_val_desc
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_item_description
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 2. Item type: mandatory, P or S
      "    (the item type decides whether goods receipts create stock movements)
      IF lr_item->ItemTypeCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_item->%tky
          %state_area           = c_val_type
          %msg                  = NEW zcx_merp_md(
                                    textid   = zcx_merp_md=>select_item_type
                                    severity = if_abap_behv_message=>severity-error )
          %element-ItemTypeCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ELSEIF lr_item->ItemTypeCode <> zif_merp_constants=>c_item_type-product
         AND lr_item->ItemTypeCode <> zif_merp_constants=>c_item_type-service.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_item->%tky
          %state_area           = c_val_type
          %msg                  = NEW zcx_merp_md(
                                    textid   = zcx_merp_md=>item_type_not_found
                                    attr1    = CONV string( lr_item->ItemTypeCode )
                                    severity = if_abap_behv_message=>severity-error )
          %element-ItemTypeCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 3. Item group: mandatory, exists
      IF lr_item->ItemGroupCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          %state_area            = c_val_group
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>select_item_group
                                     severity = if_abap_behv_message=>severity-error )
          %element-ItemGroupCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ELSEIF NOT line_exists( lt_item_groups[ ItemGroupCode = lr_item->ItemGroupCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          %state_area            = c_val_group
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>item_group_not_found
                                     attr1    = CONV string( lr_item->ItemGroupCode )
                                     severity = if_abap_behv_message=>severity-error )
          %element-ItemGroupCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 4. Default VAT code: mandatory, exists
      IF lr_item->DefaultVatCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_item->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>select_default_vat_code
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ELSEIF NOT line_exists( lt_vat_rates[ VatCode = lr_item->DefaultVatCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_item->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>vat_code_not_found
                                      attr1    = CONV string( lr_item->DefaultVatCode )
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 5. Base unit of measure: mandatory, exists
      IF lr_item->BaseUnitOfMeasure IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                       = lr_item->%tky
          %state_area                = c_val_uom
          %msg                       = NEW zcx_merp_md(
                                         textid   = zcx_merp_md=>select_base_unit
                                         severity = if_abap_behv_message=>severity-error )
          %element-BaseUnitOfMeasure = if_abap_behv=>mk-on
        ) TO reported-item.
      ELSEIF NOT line_exists( lt_units[ UnitOfMeasure = lr_item->BaseUnitOfMeasure ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                       = lr_item->%tky
          %state_area                = c_val_uom
          %msg                       = NEW zcx_merp_md(
                                         textid   = zcx_merp_md=>unit_not_found
                                         attr1    = CONV string( lr_item->BaseUnitOfMeasure )
                                         severity = if_abap_behv_message=>severity-error )
          %element-BaseUnitOfMeasure = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_item->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForFilledFields.

    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_item IN LOCAL MODE
      ENTITY Item
      FIELDS ( Description ItemTypeCode ItemGroupCode DefaultVatCode BaseUnitOfMeasure )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      IF lr_item->Description IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_desc ) TO reported-item.
      ENDIF.
      IF lr_item->ItemTypeCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_type ) TO reported-item.
      ENDIF.
      IF lr_item->ItemGroupCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_group ) TO reported-item.
      ENDIF.
      IF lr_item->DefaultVatCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_vat ) TO reported-item.
      ENDIF.
      IF lr_item->BaseUnitOfMeasure IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_uom ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

