"! Local behavior handler for Company Code BO entity.
CLASS lhc_zmerp_r_company_code DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_name   TYPE string VALUE 'VALIDATE_COMPANY_NAME',
      c_val_prefix TYPE string VALUE 'VALIDATE_COMPANY_PREFIX',
      c_val_curr   TYPE string VALUE 'VALIDATE_CURRENCY',
      c_val_cntr   TYPE string VALUE 'VALIDATE_COUNTRY'.

    TYPES:
      BEGIN OF ty_prefix_check,
        company_code   TYPE zmerp_company_code,
        company_prefix TYPE zmerp_company_prefix,
      END OF ty_prefix_check,
      tt_prefix_checks TYPE STANDARD TABLE OF ty_prefix_check WITH EMPTY KEY,

      BEGIN OF ty_prefix_conflict,
        company_code TYPE zmerp_company_code,
        owner_code   TYPE zmerp_company_code,
      END OF ty_prefix_conflict,
      tt_prefix_conflicts TYPE SORTED TABLE OF ty_prefix_conflict WITH UNIQUE KEY company_code.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR CompanyCode
        RESULT result.

    "! Companies in use keep their currency (stock valuation) and prefix (document numbers).
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR CompanyCode
      RESULT   result.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE CompanyCode.

    " --- Determinations on modify ---
    "! Converts the company prefix to upper case and interactively checks
    "! its length and uniqueness. Owns the prefix state area.
    METHODS handlePrefixChange FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CompanyCode~handlePrefixChange.

    " --- Validations ---
    "! Validates mandatory fields, prefix length and prefix uniqueness before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR CompanyCode~validateMandatoryFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages for fields that have been filled in.
    "! CompanyPrefix is handled by handlePrefixChange (clear and re-check in one place).
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CompanyCode~clearMessagesForFilledFields.

    " --- Helpers ---
    "! Returns the companies whose prefix is already used by another company
    "! (active record or draft). The same prefix would give equal document numbers.
    "! @parameter it_checks    | Company codes with the prefixes to check (upper case)
    "! @parameter rt_conflicts | Company code with the code of the company that already uses its prefix
    METHODS find_prefix_conflicts
      IMPORTING it_checks           TYPE tt_prefix_checks
      RETURNING VALUE(rt_conflicts) TYPE tt_prefix_conflicts.

ENDCLASS.

CLASS lhc_zmerp_r_company_code IMPLEMENTATION.

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
    " prefix and currency matter for documents only, a warehouse does not lock them
    DATA(lt_usages) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_usages(
      VALUE #( FOR key IN keys ( CompanyCode = key-CompanyCode ) ) ).

    result = VALUE #(
      FOR key IN keys
      LET lv_control = COND #( WHEN line_exists( lt_usages[ CompanyCode = key-CompanyCode
                                                            IsDocument  = abap_true ] )
                               THEN if_abap_behv=>fc-f-read_only
                               ELSE if_abap_behv=>fc-f-mandatory ) IN
      ( %tky                 = key-%tky
        %field-CurrencyCode  = lv_control
        %field-CompanyPrefix = lv_control )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    " Usages of all keys in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_usages(
      VALUE #( FOR key IN keys ( CompanyCode = key-CompanyCode ) ) ).

    IF lt_usages IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      IF NOT line_exists( lt_usages[ CompanyCode = lr_key->CompanyCode ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky        = lr_key->%tky
        %fail-cause = if_abap_behv=>cause-dependency
      ) TO failed-companycode.

      " One message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE CompanyCode = lr_key->CompanyCode.
        APPEND VALUE #(
          %tky                 = lr_key->%tky
          %element-CompanyCode = if_abap_behv=>mk-on
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>company_code_in_use
                                   attr1    = CONV #( lr_usage->CompanyCode )
                                   attr2    = CONV #( lr_usage->UsedInEntity )
                                   severity = if_abap_behv_message=>severity-error )
        ) TO reported-companycode.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD handlePrefixChange.
    DATA lt_update TYPE TABLE FOR UPDATE zmerp_r_company_code.

    READ ENTITIES OF zmerp_r_company_code IN LOCAL MODE
      ENTITY CompanyCode
      FIELDS ( CompanyPrefix )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_comp_codes).

    IF lt_comp_codes IS INITIAL.
      RETURN.
    ENDIF.

    " Uniqueness is checked on the upper-case value that will be stored
    DATA(lt_conflicts) = find_prefix_conflicts(
      VALUE #( FOR comp IN lt_comp_codes
               ( company_code   = comp-CompanyCode
                 company_prefix = to_upper( comp-CompanyPrefix ) ) ) ).

    LOOP AT lt_comp_codes REFERENCE INTO DATA(lr_comp_code).
      " This determination owns the prefix state area: clear it before re-checking
      APPEND VALUE #( %tky = lr_comp_code->%tky %state_area = c_val_prefix ) TO reported-companycode.

      " An empty prefix is reported on save, like all other mandatory fields
      IF lr_comp_code->CompanyPrefix IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_upper_prefix) = CONV zmerp_company_prefix( to_upper( lr_comp_code->CompanyPrefix ) ).

      IF zcl_merp_md_validator=>is_company_prefix_valid( lv_upper_prefix ) = abap_false.
        APPEND VALUE #(
          %tky                   = lr_comp_code->%tky
          %state_area            = c_val_prefix
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>invalid_prefix_length
                                     severity = if_abap_behv_message=>severity-error )
          %element-CompanyPrefix = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ELSE.
        ASSIGN lt_conflicts[ company_code = lr_comp_code->CompanyCode ] TO FIELD-SYMBOL(<ls_conflict>).
        IF sy-subrc = 0.
          APPEND VALUE #(
            %tky                   = lr_comp_code->%tky
            %state_area            = c_val_prefix
            %msg                   = NEW zcx_merp_md(
                                       textid   = zcx_merp_md=>company_prefix_not_unique
                                       attr1    = CONV #( lv_upper_prefix )
                                       attr2    = CONV #( <ls_conflict>-owner_code )
                                       severity = if_abap_behv_message=>severity-error )
            %element-CompanyPrefix = if_abap_behv=>mk-on
          ) TO reported-companycode.
        ENDIF.
      ENDIF.

      " Store the prefix in upper case (document numbers start with it)
      IF lr_comp_code->CompanyPrefix <> lv_upper_prefix.
        APPEND VALUE #(
          %tky                   = lr_comp_code->%tky
          CompanyPrefix          = lv_upper_prefix
          %control-CompanyPrefix = if_abap_behv=>mk-on
        ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_company_code IN LOCAL MODE
        ENTITY CompanyCode
        UPDATE FIELDS ( CompanyPrefix )
        WITH lt_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateMandatoryFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear the messages of the previous validation run
    reported-companycode = VALUE #(
      BASE reported-companycode
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_name )
      ( %tky        = key-%tky
        %state_area = c_val_prefix )
      ( %tky        = key-%tky
        %state_area = c_val_curr )
      ( %tky        = key-%tky
        %state_area = c_val_cntr )
    ).

    READ ENTITIES OF zmerp_r_company_code IN LOCAL MODE
      ENTITY CompanyCode
      FIELDS ( CompanyName CompanyPrefix CurrencyCode Country )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_comp_codes).

    IF lt_comp_codes IS INITIAL.
      RETURN.
    ENDIF.

    " The prefix is already upper case here (handlePrefixChange converts it on every change)
    DATA(lt_conflicts) = find_prefix_conflicts(
      VALUE #( FOR comp IN lt_comp_codes
               ( company_code   = comp-CompanyCode
                 company_prefix = comp-CompanyPrefix ) ) ).

    " SAP standard master data referenced by the companies (one selection each)
    DATA(lo_sap_md_sel) = CAST zif_merp_md_sap_sel( NEW zcl_merp_md_sap_sel( ) ).

    DATA(lt_currencies) = lo_sap_md_sel->read_currencies(
      VALUE #( FOR comp IN lt_comp_codes ( Currency = comp-CurrencyCode ) )
    ).

    DATA(lt_countries) = lo_sap_md_sel->read_countries(
      VALUE #( FOR comp IN lt_comp_codes ( Country = comp-Country ) )
    ).

    LOOP AT lt_comp_codes REFERENCE INTO DATA(lr_comp_code).
      lv_has_error = abap_false.

      " 1. Name: mandatory
      IF lr_comp_code->CompanyName IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_comp_code->%tky
          %state_area          = c_val_name
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_company_name
                                   severity = if_abap_behv_message=>severity-error )
          %element-CompanyName = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ENDIF.

      " 2. Prefix: mandatory, exactly 2 characters, unique
      IF lr_comp_code->CompanyPrefix IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_comp_code->%tky
          %state_area            = c_val_prefix
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>enter_company_prefix
                                     severity = if_abap_behv_message=>severity-error )
          %element-CompanyPrefix = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ELSEIF zcl_merp_md_validator=>is_company_prefix_valid( lr_comp_code->CompanyPrefix ) = abap_false.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_comp_code->%tky
          %state_area            = c_val_prefix
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>invalid_prefix_length
                                     severity = if_abap_behv_message=>severity-error )
          %element-CompanyPrefix = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ELSE.
        ASSIGN lt_conflicts[ company_code = lr_comp_code->CompanyCode ] TO FIELD-SYMBOL(<ls_conflict>).
        IF sy-subrc = 0.
          lv_has_error = abap_true.
          APPEND VALUE #(
            %tky                   = lr_comp_code->%tky
            %state_area            = c_val_prefix
            %msg                   = NEW zcx_merp_md(
                                       textid   = zcx_merp_md=>company_prefix_not_unique
                                       attr1    = CONV #( lr_comp_code->CompanyPrefix )
                                       attr2    = CONV #( <ls_conflict>-owner_code )
                                       severity = if_abap_behv_message=>severity-error )
            %element-CompanyPrefix = if_abap_behv=>mk-on
          ) TO reported-companycode.
        ENDIF.
      ENDIF.

      " 3. Currency: mandatory, exists
      IF lr_comp_code->CurrencyCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_comp_code->%tky
          %state_area           = c_val_curr
          %msg                  = NEW zcx_merp_md(
                                    textid   = zcx_merp_md=>select_currency
                                    severity = if_abap_behv_message=>severity-error )
          %element-CurrencyCode = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ELSEIF NOT line_exists( lt_currencies[ Currency = lr_comp_code->CurrencyCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_comp_code->%tky
          %state_area           = c_val_curr
          %msg                  = NEW zcx_merp_md(
                                    textid   = zcx_merp_md=>currency_not_found
                                    attr1    = CONV string( lr_comp_code->CurrencyCode )
                                    severity = if_abap_behv_message=>severity-error )
          %element-CurrencyCode = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ENDIF.

      " 4. Country: mandatory, exists
      IF lr_comp_code->Country IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky              = lr_comp_code->%tky
          %state_area       = c_val_cntr
          %msg              = NEW zcx_merp_md(
                                textid   = zcx_merp_md=>select_country
                                severity = if_abap_behv_message=>severity-error )
          %element-Country  = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ELSEIF NOT line_exists( lt_countries[ Country = lr_comp_code->Country ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky              = lr_comp_code->%tky
          %state_area       = c_val_cntr
          %msg              = NEW zcx_merp_md(
                                textid   = zcx_merp_md=>country_not_found
                                attr1    = CONV string( lr_comp_code->Country )
                                severity = if_abap_behv_message=>severity-error )
          %element-Country  = if_abap_behv=>mk-on
        ) TO reported-companycode.
      ENDIF.

      IF lv_has_error = abap_true.
        " Any error fails the instance
        APPEND VALUE #(
          %tky        = lr_comp_code->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-companycode.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_company_code IN LOCAL MODE
      ENTITY CompanyCode
      FIELDS ( CompanyName CurrencyCode Country )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_comp_codes).

    LOOP AT lt_comp_codes REFERENCE INTO DATA(lr_comp_code).
      " Clear message area for Company Name
      IF lr_comp_code->CompanyName IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_comp_code->%tky %state_area = c_val_name ) TO reported-companycode.
      ENDIF.

      " Clear message area for Currency Code
      IF lr_comp_code->CurrencyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_comp_code->%tky %state_area = c_val_curr ) TO reported-companycode.
      ENDIF.

      " Clear message area for Country
      IF lr_comp_code->Country IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_comp_code->%tky %state_area = c_val_cntr ) TO reported-companycode.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Helpers ---
  METHOD find_prefix_conflicts.
    TYPES: BEGIN OF ty_prefix,
             company_prefix TYPE zmerp_company_prefix,
           END OF ty_prefix.

    DATA lt_prefixes TYPE SORTED TABLE OF ty_prefix WITH UNIQUE KEY company_prefix.
    DATA lt_owners   TYPE tt_prefix_checks.

    LOOP AT it_checks REFERENCE INTO DATA(lr_check) WHERE company_prefix IS NOT INITIAL.
      INSERT VALUE #( company_prefix = lr_check->company_prefix ) INTO TABLE lt_prefixes.
    ENDLOOP.

    IF lt_prefixes IS INITIAL.
      RETURN.
    ENDIF.

    " Only active companies are checked: a draft with the same prefix fails on its own activation
    SELECT comp~CompanyCode   AS company_code,
           comp~CompanyPrefix AS company_prefix
      FROM zmerp_r_company_code AS comp
      INNER JOIN @lt_prefixes AS pref ON comp~CompanyPrefix = pref~company_prefix
      INTO CORRESPONDING FIELDS OF TABLE @lt_owners.

    " A company's own active record is not a conflict
    LOOP AT it_checks REFERENCE INTO lr_check WHERE company_prefix IS NOT INITIAL.
      LOOP AT lt_owners REFERENCE INTO DATA(lr_owner)
           WHERE company_prefix = lr_check->company_prefix
             AND company_code  <> lr_check->company_code.
        INSERT VALUE #( company_code = lr_check->company_code
                        owner_code   = lr_owner->company_code ) INTO TABLE rt_conflicts.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

"! Saver for Company Code: a new company gets its document number range intervals (purchase orders,
"! goods receipts) in the same save, so its documents are numbered by NRO from the first one
"! and not by the database maximum (fallback, not protected against parallel saves).
CLASS lsc_zmerp_r_company_code DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_zmerp_r_company_code IMPLEMENTATION.

  METHOD save_modified.
    " A new company has no documents yet: its document intervals start at level zero
    LOOP AT create-companycode REFERENCE INTO DATA(lr_company).
      zcl_merp_nro_admin_util=>reset_company_doc_intervals( lr_company->CompanyCode ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


