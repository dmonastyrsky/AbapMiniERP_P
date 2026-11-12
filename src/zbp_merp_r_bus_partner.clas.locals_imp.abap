"! Local behavior handler for Business Partner BO entity.
CLASS lhc_zmerp_r_bus_partner DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_name TYPE string VALUE 'VALIDATE_PARTNER_NAME',
      c_val_role TYPE string VALUE 'VALIDATE_PARTNER_ROLE',
      c_val_cntr TYPE string VALUE 'VALIDATE_COUNTRY'.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR BusinessPartner
      RESULT result.

    "! Partners used in purchasing documents stay suppliers, partners used in sales documents stay customers
    "! (the documents require the role flag).
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR BusinessPartner
      RESULT   result.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE BusinessPartner.

    " --- Numbering ---
    "! Assigns early numbers for new Business Partner entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE BusinessPartner.

    " --- Validations ---
    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR BusinessPartner~validateMandatoryFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BusinessPartner~clearMessagesForFilledFields.

ENDCLASS.


CLASS lhc_zmerp_r_bus_partner IMPLEMENTATION.

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
    " Current role flags: only a set flag is locked, an unset flag can always be set
    READ ENTITIES OF zmerp_r_bus_partner IN LOCAL MODE
      ENTITY BusinessPartner
      FIELDS ( IsSupplier IsCustomer )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_partners).

    IF lt_partners IS INITIAL.
      RETURN.
    ENDIF.

    " A role used in documents keeps its flag (one selection for all keys)
    DATA(lt_usages) = NEW zcl_merp_md_bus_partner_sel( )->zif_merp_md_bus_partner_sel~read_usages(
      VALUE #( FOR partner IN lt_partners ( PartnerCode = partner-PartnerCode ) ) ).

    result = VALUE #(
      FOR partner IN lt_partners
      ( %tky              = partner-%tky
        %field-IsSupplier = COND #( WHEN partner-IsSupplier = abap_true
                                     AND line_exists( lt_usages[ PartnerCode    = partner-PartnerCode
                                                                 UsedAsSupplier = abap_true ] )
                                    THEN if_abap_behv=>fc-f-read_only
                                    ELSE if_abap_behv=>fc-f-unrestricted )
        %field-IsCustomer = COND #( WHEN partner-IsCustomer = abap_true
                                     AND line_exists( lt_usages[ PartnerCode    = partner-PartnerCode
                                                                 UsedAsCustomer = abap_true ] )
                                    THEN if_abap_behv=>fc-f-read_only
                                    ELSE if_abap_behv=>fc-f-unrestricted ) )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    " Usages of all keys in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_md_bus_partner_sel( )->zif_merp_md_bus_partner_sel~read_usages(
      VALUE #( FOR key IN keys ( PartnerCode = key-PartnerCode ) ) ).

    IF lt_usages IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      IF NOT line_exists( lt_usages[ PartnerCode = lr_key->PartnerCode ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky        = lr_key->%tky
        %fail-cause = if_abap_behv=>cause-dependency
      ) TO failed-businesspartner.

      " One message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE PartnerCode = lr_key->PartnerCode.
        APPEND VALUE #(
          %tky                 = lr_key->%tky
          %element-PartnerCode = if_abap_behv=>mk-on
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>business_partner_in_use
                                   attr1    = CONV #( lr_usage->PartnerCode )
                                   attr2    = CONV #( lr_usage->UsedInEntity )
                                   severity = if_abap_behv_message=>severity-error )
        ) TO reported-businesspartner.
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
                                       WHERE ( PartnerCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_md_codes( is_meta  = zif_merp_constants=>c_bp
                                                             iv_count = lv_needed_count ).
        CATCH cx_number_ranges INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->PartnerCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            PartnerCode = CONV #( <lv_code> )
          ) TO mapped-businesspartner.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-businesspartner.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>bus_part_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-businesspartner.
        ENDIF.
      ELSE.
        " Key already assigned (draft activation passes the draft key): keep it, no new number is drawn
        APPEND VALUE #(
          %cid        = lr_entity->%cid
          %is_draft   = lr_entity->%is_draft
          PartnerCode = lr_entity->PartnerCode
        ) TO mapped-businesspartner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateMandatoryFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear the messages of the previous validation run
    reported-businesspartner = VALUE #(
      BASE reported-businesspartner
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_name )
      ( %tky        = key-%tky
        %state_area = c_val_role )
      ( %tky        = key-%tky
        %state_area = c_val_cntr )
    ).

    READ ENTITIES OF zmerp_r_bus_partner IN LOCAL MODE
      ENTITY BusinessPartner
      FIELDS ( PartnerName IsCustomer IsSupplier Country )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_partners).

    IF lt_partners IS INITIAL.
      RETURN.
    ENDIF.

    " Countries of the partners (one selection; initial countries are skipped by the selector)
    DATA(lt_countries) = NEW zcl_merp_md_sap_sel( )->zif_merp_md_sap_sel~read_countries(
      VALUE #( FOR partner IN lt_partners ( Country = partner-Country ) )
    ).

    LOOP AT lt_partners REFERENCE INTO DATA(lr_partner).
      lv_has_error = abap_false.

      " 1. Name: mandatory
      IF lr_partner->PartnerName IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_partner->%tky
          %state_area          = c_val_name
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_partner_name
                                   severity = if_abap_behv_message=>severity-error )
          %element-PartnerName = if_abap_behv=>mk-on
        ) TO reported-businesspartner.
      ENDIF.

      " 2. Roles: at least one of customer and supplier
      IF lr_partner->IsCustomer IS INITIAL AND lr_partner->IsSupplier IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                = lr_partner->%tky
          %state_area         = c_val_role
          %msg                = NEW zcx_merp_md(
                                  textid   = zcx_merp_md=>select_partner_role
                                  severity = if_abap_behv_message=>severity-error )
          %element-IsCustomer = if_abap_behv=>mk-on
          %element-IsSupplier = if_abap_behv=>mk-on
        ) TO reported-businesspartner.
      ENDIF.

      " 3. Country: optional, must exist when entered
      IF lr_partner->Country IS NOT INITIAL
         AND NOT line_exists( lt_countries[ Country = lr_partner->Country ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky             = lr_partner->%tky
          %state_area      = c_val_cntr
          %msg             = NEW zcx_merp_md(
                               textid   = zcx_merp_md=>country_not_found
                               attr1    = CONV string( lr_partner->Country )
                               severity = if_abap_behv_message=>severity-error )
          %element-Country = if_abap_behv=>mk-on
        ) TO reported-businesspartner.
      ENDIF.

      IF lv_has_error = abap_true.
        " Any error fails the instance
        APPEND VALUE #(
          %tky        = lr_partner->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-businesspartner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_bus_partner IN LOCAL MODE
      ENTITY BusinessPartner
      FIELDS ( PartnerName IsCustomer IsSupplier )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_partners).

    LOOP AT lt_partners REFERENCE INTO DATA(lr_partner).
      " Clear message area for Business Partner Name
      IF lr_partner->PartnerName IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_partner->%tky %state_area = c_val_name ) TO reported-businesspartner.
      ENDIF.

      " Clear message area for Partner Roles if at least one checkbox is set
      IF lr_partner->IsCustomer IS NOT INITIAL OR lr_partner->IsSupplier IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_partner->%tky %state_area = c_val_role ) TO reported-businesspartner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

