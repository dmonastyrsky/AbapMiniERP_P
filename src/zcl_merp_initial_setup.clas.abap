"! Initial seed data population runner for Mini ERP application.
CLASS zcl_merp_initial_setup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    "! Executes complete initial seed data setup for all master data entities and syncs NRO levels.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS execute
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

  PROTECTED SECTION.
  PRIVATE SECTION.

    "! Retrieves the current technical user name or falls back to default.
    CLASS-METHODS get_current_user
      RETURNING
        VALUE(rv_user) TYPE abp_creation_user .

    "! Retrieves the current system timestamp.
    CLASS-METHODS get_current_timestamp
      RETURNING
        VALUE(rv_timestamp) TYPE abp_creation_tstmpl .

    "! Fills common administrative audit fields for a given internal table.
    "! @parameter ct_data | Internal table containing standard audit fields
    CLASS-METHODS fill_audit_fields
      CHANGING
        ct_data TYPE ANY TABLE .

    "! Writes a text line to the console runner if bound.
    CLASS-METHODS write_log
      IMPORTING
        iv_text TYPE string
        out     TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Logs successful database insert status for an entity.
    CLASS-METHODS write_insert_log
      IMPORTING
        iv_entity_name TYPE string
        iv_count       TYPE i
        out            TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Clears active and draft database tables for a setup domain.
    CLASS-METHODS clear_table_data
      IMPORTING
        iv_active_table TYPE tabname
        iv_draft_table  TYPE tabname OPTIONAL .

    "! Populates initial company codes seed data into ZMERP_COMP_CODE table.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS setup_company_codes
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates initial warehouses seed data into ZMERP_WAREHOUSE table.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS setup_warehouses
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates initial VAT rates seed data into ZMERP_VAT_RATE table.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS setup_vat_rates
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates initial item groups seed data into ZMERP_ITEM_GROUP table.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS setup_item_groups
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates initial master items/products seed data into ZMERP_ITEM table.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS setup_items
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates initial business partners seed data into ZMERP_BUS_PART table.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS setup_business_partners
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Generates initial business transactional documents (Purchase Orders).
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS setup_purchase_orders
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

ENDCLASS.

CLASS zcl_merp_initial_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    execute( out ).
  ENDMETHOD.

  METHOD execute.
    write_log( iv_text = '=== Starting Initial Data Setup for Mini ERP ===' out = out ).

    " Insert seed data using formatted keys and interface constants
    setup_company_codes( out ).
    setup_vat_rates( out ).
    setup_warehouses( out ).
    setup_item_groups( out ).
    setup_items( out ).
    setup_business_partners( out ).

    setup_purchase_orders( out ).

    " Dynamically sync NRO levels with real DB record counts
    zcl_merp_num_range_util=>sync_intervals_from_db( ).

    write_log( iv_text = '==== Initial Data Setup Completed Successfully ====' out = out ).
  ENDMETHOD.

  METHOD write_insert_log.
    write_log(
      iv_text = |[{ iv_entity_name }]: Successfully inserted { iv_count } rows.|
      out     = out
    ).
  ENDMETHOD.

  METHOD get_current_user.
    TRY.
        rv_user = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        rv_user = 'INITIAL_SETUP'.
    ENDTRY.
  ENDMETHOD.

  METHOD get_current_timestamp.
    GET TIME STAMP FIELD rv_timestamp.
  ENDMETHOD.

  METHOD write_log.
    IF out IS BOUND.
      out->write( iv_text ).
    ENDIF.
  ENDMETHOD.

  METHOD fill_audit_fields.
    DATA(lv_user)      = get_current_user( ).
    DATA(lv_timestamp) = get_current_timestamp( ).

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_row>).
      ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_cb>).
      IF sy-subrc = 0. <lv_cb> = lv_user. ENDIF.

      ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_ca>).
      IF sy-subrc = 0. <lv_ca> = lv_timestamp. ENDIF.

      ASSIGN COMPONENT 'LOCAL_LAST_CHANGED_BY' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_lcb>).
      IF sy-subrc = 0. <lv_lcb> = lv_user. ENDIF.

      ASSIGN COMPONENT 'LOCAL_LAST_CHANGED_AT' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_lca>).
      IF sy-subrc = 0. <lv_lca> = lv_timestamp. ENDIF.

      ASSIGN COMPONENT 'LAST_CHANGED_AT' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_lch>).
      IF sy-subrc = 0. <lv_lch> = lv_timestamp. ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setup_company_codes.
    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_comp-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_comp-table_draft )
    ).

    DATA lt_comp_code TYPE TABLE OF zmerp_comp_code.

    lt_comp_code = VALUE #(
      ( company_code   = '1000'
        company_name   = 'MERP Deutschland GmbH'
        company_prefix = 'DE'
        currency_code  = 'EUR'
        country        = 'DE' )

      ( company_code   = '2000'
        company_name   = 'MERP Trading GmbH'
        company_prefix = 'TR'
        currency_code  = 'EUR'
        country        = 'DE' )

      ( company_code   = '3000'
        company_name   = 'Modevi GmbH'
        company_prefix = 'MD'
        currency_code  = 'EUR'
        country        = 'DE' )

      ( company_code   = '4000'
        company_name   = 'MERP Inactive Services GmbH'
        company_prefix = 'IS'
        currency_code  = 'EUR'
        country        = 'DE'
        is_blocked     = abap_true )
    ).

    fill_audit_fields( CHANGING ct_data = lt_comp_code ).

    INSERT zmerp_comp_code FROM TABLE @lt_comp_code.
    write_insert_log( iv_entity_name = 'Company Code' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

  METHOD setup_vat_rates.
    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_vat-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_vat-table_draft )
    ).

    DATA lt_vat_rates TYPE TABLE OF zmerp_vat_rate.

    lt_vat_rates = VALUE #(
      ( vat_code    = zcl_merp_format_util=>format_vat_code( 1 )
        description = 'VAT 0%'
        percentage  = '0.00' )

      ( vat_code    = zcl_merp_format_util=>format_vat_code( 2 )
        description = 'VAT 7%'
        percentage  = '7.00' )

      ( vat_code    = zcl_merp_format_util=>format_vat_code( 3 )
        description = 'VAT 19%'
        percentage  = '19.00' )

      ( vat_code    = zcl_merp_format_util=>format_vat_code( 4 )
        description = 'VAT 16% (Historical)'
        percentage  = '16.00'
        is_blocked  = abap_true )
    ).

    fill_audit_fields( CHANGING ct_data = lt_vat_rates ).

    INSERT zmerp_vat_rate FROM TABLE @lt_vat_rates.
    write_insert_log( iv_entity_name = 'VAT Rate' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

  METHOD setup_warehouses.
    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_wh-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_wh-table_draft )
    ).

    DATA lt_warehouses TYPE TABLE OF zmerp_warehouse.

    lt_warehouses = VALUE #(
      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 1 )
        warehouse_name = 'Hauptlager Kusel'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 2 )
        warehouse_name = 'Hauptlager Frankfurt'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 3 )
        warehouse_name = 'Lager Berlin'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 4 )
        warehouse_name = 'Retourlager Frankfurt'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 5 )
        warehouse_name = 'Hauptlager Hamburg'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 6 )
        warehouse_name = 'Lager München'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 7 )
        warehouse_name = 'Transitlager Hamburg'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 8 )
        warehouse_name = 'Altlager Frankfurt'
        company_code   = '1000'
        is_blocked     = abap_true )
    ).

    fill_audit_fields( CHANGING ct_data = lt_warehouses ).

    INSERT zmerp_warehouse FROM TABLE @lt_warehouses.
    write_insert_log( iv_entity_name = 'Warehouse' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

  METHOD setup_item_groups.
    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_ig-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_ig-table_draft )
    ).

    DATA(lv_vat19) = zcl_merp_format_util=>format_vat_code( 3 ).
    DATA(lv_vat7)  = zcl_merp_format_util=>format_vat_code( 2 ).

    DATA lt_item_groups TYPE TABLE OF zmerp_item_group.

    lt_item_groups = VALUE #(
      ( item_group_code  = zcl_merp_format_util=>format_item_grp_code( 1 )
        description      = 'Major Home Appliances'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_format_util=>format_item_grp_code( 2 )
        description      = 'Small Kitchen Appliances'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_format_util=>format_item_grp_code( 3 )
        description      = 'Consumer Electronics'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_format_util=>format_item_grp_code( 4 )
        description      = 'Accessories & Supplies'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_format_util=>format_item_grp_code( 5 )
        description      = 'Installation & Support Services'
        default_vat_code = lv_vat7 )

      ( item_group_code  = zcl_merp_format_util=>format_item_grp_code( 6 )
        description      = 'Legacy Office Equipment'
        default_vat_code = lv_vat19
        is_blocked       = abap_true )
    ).

    fill_audit_fields( CHANGING ct_data = lt_item_groups ).

    INSERT zmerp_item_group FROM TABLE @lt_item_groups.
    write_insert_log( iv_entity_name = 'Item Group' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

  METHOD setup_items.
    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_item-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_item-table_draft )
    ).

    " Formatted Group Codes
    DATA(lv_grp1) = zcl_merp_format_util=>format_item_grp_code( 1 ).
    DATA(lv_grp2) = zcl_merp_format_util=>format_item_grp_code( 2 ).
    DATA(lv_grp3) = zcl_merp_format_util=>format_item_grp_code( 3 ).
    DATA(lv_grp4) = zcl_merp_format_util=>format_item_grp_code( 4 ).
    DATA(lv_grp5) = zcl_merp_format_util=>format_item_grp_code( 5 ).
    DATA(lv_grp6) = zcl_merp_format_util=>format_item_grp_code( 6 ).

    DATA lt_items TYPE TABLE OF zmerp_item.

    lt_items = VALUE #(
      " Group 1: Major Home Appliances
      ( item_code            = zcl_merp_format_util=>format_item_code( 1 )
        description          = 'Washing Machine Bosch Series 6'
        article              = 'BSH-WM-600'
        item_type            = 'P'
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 2 )
        description          = 'Refrigerator Siemens iQ500'
        article              = 'SIE-RF-500'
        item_type            = 'P'
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 3 )
        description          = 'Dishwasher Miele G7000'
        article              = 'MIE-DW-700'
        item_type            = 'P'
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )

      " Group 2: Small Kitchen Appliances
      ( item_code            = zcl_merp_format_util=>format_item_code( 4 )
        description          = 'Espresso Machine DeLonghi Magnifica'
        article              = 'DLG-EM-100'
        item_type            = 'P'
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 5 )
        description          = 'Electric Kettle Philips Daily Collection'
        article              = 'PHL-EK-200'
        item_type            = 'P'
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 6 )
        description          = 'Toaster Tefal Express 2-Slot'
        article              = 'TEF-TS-300'
        item_type            = 'P'
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )

      " Group 3: Consumer Electronics
      ( item_code            = zcl_merp_format_util=>format_item_code( 7 )
        description          = 'Smart TV Samsung 55 Inch OLED'
        article              = 'SAM-TV-55O'
        item_type            = 'P'
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 8 )
        description          = 'Soundbar Sony HT-S400 2.1ch'
        article              = 'SNE-SB-400'
        item_type            = 'P'
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 9 )
        description          = 'Wireless Headphones Bose QuietComfort 45'
        article              = 'BOS-HP-QC45'
        item_type            = 'P'
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )

      " Group 4: Accessories & Supplies
      ( item_code            = zcl_merp_format_util=>format_item_code( 10 )
        description          = 'HDMI Cable 2.0 High Speed (2m)'
        article              = 'ACC-HDMI-02'
        item_type            = 'P'
        item_group_code      = lv_grp4
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 11 )
        description          = 'Washing Machine Water Inlet Hose (1.5m)'
        article              = 'ACC-HOSE-15'
        item_type            = 'P'
        item_group_code      = lv_grp4
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 12 )
        description          = 'Descaling Solution for Coffee Machines 500ml'
        article              = 'ACC-DESC-50'
        item_type            = 'P'
        item_group_code      = lv_grp4
        base_unit_of_measure = 'BOT' )

      " Group 5: Installation & Support Services
      ( item_code            = zcl_merp_format_util=>format_item_code( 13 )
        description          = 'Home Appliance Installation Service'
        article              = 'SRV-INST-01'
        item_type            = 'S'
        item_group_code      = lv_grp5
        base_unit_of_measure = 'H' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 14 )
        description          = 'Extended Warranty & On-site Repair Service'
        article              = 'SRV-REPR-02'
        item_type            = 'S'
        item_group_code      = lv_grp5
        base_unit_of_measure = 'H' )

       " Group 6: Legacy Office Equipment (Blocked)
       ( item_code            = zcl_merp_format_util=>format_item_code( 15 )
        description          = 'Siemens Optipoint 500 Entry'
        article              = 'SIE-TEL-500'
        item_type            = 'P'
        item_group_code      = lv_grp6
        base_unit_of_measure = 'EA'
        is_blocked           = abap_true )
    ).

    " Bulk-mode item group fetching via interface implementation
    DATA lt_grp_keys TYPE zif_merp_md_item_group_sel=>tt_item_group_keys.
    lt_grp_keys = VALUE #( FOR GROUPS grp OF item IN lt_items GROUP BY item-item_group_code ( ItemGroupCode = grp ) ).

    DATA(lo_item_grp_sel) = NEW zcl_merp_md_item_group_sel( ).
    DATA(lt_item_groups)  = lo_item_grp_sel->zif_merp_md_item_group_sel~read_item_groups( lt_grp_keys ).

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      ASSIGN lt_item_groups[ ItemGroupCode = <ls_item>-item_group_code ] TO FIELD-SYMBOL(<ls_grp>).
      IF sy-subrc = 0.
        <ls_item>-default_vat_code = <ls_grp>-DefaultVatCode.
      ENDIF.
    ENDLOOP.

    fill_audit_fields( CHANGING ct_data = lt_items ).

    INSERT zmerp_item FROM TABLE @lt_items.
    write_insert_log( iv_entity_name = 'Item' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

  METHOD setup_business_partners.
    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_bp-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_bp-table_draft )
    ).

    DATA lt_bp TYPE TABLE OF zmerp_bus_part.

    lt_bp = VALUE #(
      " --- Suppliers ---
      ( partner_code = zcl_merp_format_util=>format_bp_code( 1 )
        partner_name = 'Bosch-Siemens Hausgeräte GmbH'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE129323400'
        address      = 'Carl-Wery-Straße 34'
        city         = 'München'
        country      = 'DE'
        phone        = '+49 89 459001'
        email        = 'contact@bshg.com' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 2 )
        partner_name = 'Miele & Cie. KG'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE126788901'
        address      = 'Carl-Miele-Straße 29'
        city         = 'Gütersloh'
        country      = 'DE'
        phone        = '+49 5241 890'
        email        = 'info@miele.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 3 )
        partner_name = 'DeLonghi Deutschland GmbH'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE811234567'
        address      = 'Carl-Ulrich-Straße 4'
        city         = 'Neu-Isenburg'
        country      = 'DE'
        phone        = '+49 6102 5990'
        email        = 'service@delonghi.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 4 )
        partner_name = 'Samsung Electronics GmbH'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE113546789'
        address      = 'Am Kronberger Hang 6'
        city         = 'Schwalbach am Taunus'
        country      = 'DE'
        phone        = '+49 6196 660'
        email        = 'info@samsung.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 5 )
        partner_name = 'Sony Europe B.V. Zweigniederlassung Deutschland'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE815678910'
        address      = 'Kemperplatz 1'
        city         = 'Berlin'
        country      = 'DE'
        phone        = '+49 30 585800'
        email        = 'info@sony.de' )

      " --- Customers ---
      ( partner_code = zcl_merp_format_util=>format_bp_code( 6 )
        partner_name = 'Media-Saturn Retail Group GmbH'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE130123456'
        address      = 'Media-Saturn-Str. 1'
        city         = 'Ingolstadt'
        country      = 'DE'
        phone        = '+49 841 6340'
        email        = 'einkauf@mediamarkt.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 7 )
        partner_name = 'Expert SE'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE115678123'
        address      = 'Bayernstraße 4'
        city         = 'Langenhagen'
        country      = 'DE'
        phone        = '+49 511 78080'
        email        = 'zentrale@expert.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 8 )
        partner_name = 'Euronics Deutschland eG'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE147890123'
        address      = 'Berliner Straße 11'
        city         = 'Ditzingen'
        country      = 'DE'
        phone        = '+49 7156 9280'
        email        = 'info@euronics.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 9 )
        partner_name = 'Elektro-Service Müller GmbH'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE289012345'
        address      = 'Trierer Straße 12'
        city         = 'Kusel'
        country      = 'DE'
        phone        = '+49 6381 1234'
        email        = 'service@elektro-mueller.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 10 )
        partner_name = 'Küchenstudio Schmidt GmbH'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE301234567'
        address      = 'Zeil 45'
        city         = 'Frankfurt am Main'
        country      = 'DE'
        phone        = '+49 69 987654'
        email        = 'vertrieb@kuechen-schmidt.de' )

      " --- Both ---
      ( partner_code = zcl_merp_format_util=>format_bp_code( 11 )
        partner_name = 'ElectronicPartner GmbH & Co. KG'
        is_customer  = abap_true
        is_supplier  = abap_true
        tax_number   = 'DE119345678'
        address      = 'Mündelheimer Weg 40'
        city         = 'Düsseldorf'
        country      = 'DE'
        phone        = '+49 211 41560'
        email        = 'partner@electronicpartner.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 12 )
        partner_name = 'Conrad Electronic SE'
        is_customer  = abap_true
        is_supplier  = abap_true
        tax_number   = 'DE133123789'
        address      = 'Klaus-Conrad-Straße 1'
        city         = 'Hirschau'
        country      = 'DE'
        phone        = '+49 9622 300'
        email        = 'b2b@conrad.de' )

      ( partner_code = zcl_merp_format_util=>format_bp_code( 13 )
        partner_name = 'Radio Shack GmbH'
        is_customer  = abap_true
        is_supplier  = abap_true
        tax_number   = 'DE149990123'
        address      = 'Hanauer Landstraße 150'
        city         = 'Frankfurt am Main'
        country      = 'DE'
        phone        = '+49 69 450012'
        email        = 'info@radioshack.de'
        is_blocked   = abap_true )

    ).

    fill_audit_fields( CHANGING ct_data = lt_bp ).

    INSERT zmerp_bus_part FROM TABLE @lt_bp.
    write_insert_log( iv_entity_name = 'Business Partner' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

  METHOD setup_purchase_orders.
    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_po_itm-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_po_itm-table_draft )
    ).

    clear_table_data(
      iv_active_table = CONV tabname( zif_merp_constants=>c_po-table_db )
      iv_draft_table  = CONV tabname( zif_merp_constants=>c_po-table_draft )
    ).

    DATA lt_headers    TYPE TABLE OF zmerp_po_hdr.
    DATA lt_items      TYPE TABLE OF zmerp_po_itm.
    DATA lt_calc_items TYPE zcl_merp_doc_calc=>tt_item_amounts.

    DATA(lv_today)     = cl_abap_context_info=>get_system_date( ).

    DATA(lo_item_sel)  = NEW zcl_merp_md_item_sel( ).
    DATA(lo_vat_sel)   = NEW zcl_merp_md_vat_rate_sel( ).

    DATA(lt_item_keys) = VALUE zif_merp_md_item_sel=>tt_item_keys(
      ( ItemCode = zcl_merp_format_util=>format_item_code( 1 ) )
      ( ItemCode = zcl_merp_format_util=>format_item_code( 2 ) )
      ( ItemCode = zcl_merp_format_util=>format_item_code( 7 ) )
      ( ItemCode = zcl_merp_format_util=>format_item_code( 10 ) )
    ).
    DATA(lt_items_master) = lo_item_sel->zif_merp_md_item_sel~read_items( lt_item_keys ).

    DATA(lt_vat_keys) = VALUE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys(
      ( VatCode = zcl_merp_format_util=>format_vat_code( 3 ) )
    ).
    DATA(lt_vat_master) = lo_vat_sel->zif_merp_md_vat_rate_sel~read_vat_rates( lt_vat_keys ).

    " Purchase Order 1 for company 1000
    TRY.
        DATA(lv_hd_uuid1) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_it_uuid1) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_it_uuid2) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
    ENDTRY.

    CLEAR lt_calc_items.

    ASSIGN lt_items_master[ ItemCode = zcl_merp_format_util=>format_item_code( 1 ) ] TO FIELD-SYMBOL(<ls_m1>).
    ASSIGN lt_vat_master[ VatCode = <ls_m1>-DefaultVatCode ] TO FIELD-SYMBOL(<ls_v1>).

    DATA(ls_amt1) = zcl_merp_doc_calc=>calc_on_qty_price_change(
      iv_quantity       = 2
      iv_price          = '550.00'
      iv_vat_percentage = CONV decfloat34( <ls_v1>-Percentage ) ).
    APPEND ls_amt1 TO lt_calc_items.

    APPEND VALUE #(
      item_uuid          = lv_it_uuid1
      header_uuid        = lv_hd_uuid1
      item_no            = 10
      item_code          = <ls_m1>-ItemCode
      quantity           = 2
      unit_of_measure    = <ls_m1>-BaseUnitOfMeasure
      currency_code      = 'EUR'
      price              = '550.00'
      net_amount         = ls_amt1-net_amount
      vat_code           = <ls_m1>-DefaultVatCode
      vat_amount         = ls_amt1-vat_amount
      gross_amount       = ls_amt1-gross_amount
      delivery_completed = abap_false
    ) TO lt_items.

    ASSIGN lt_items_master[ ItemCode = zcl_merp_format_util=>format_item_code( 2 ) ] TO FIELD-SYMBOL(<ls_m2>).

    DATA(ls_amt2) = zcl_merp_doc_calc=>calc_on_qty_price_change(
      iv_quantity       = 1
      iv_price          = '850.00'
      iv_vat_percentage = CONV decfloat34( <ls_v1>-Percentage ) ).
    APPEND ls_amt2 TO lt_calc_items.

    APPEND VALUE #(
      item_uuid          = lv_it_uuid2
      header_uuid        = lv_hd_uuid1
      item_no            = 20
      item_code          = <ls_m2>-ItemCode
      quantity           = 1
      unit_of_measure    = <ls_m2>-BaseUnitOfMeasure
      currency_code      = 'EUR'
      price              = '850.00'
      net_amount         = ls_amt2-net_amount
      vat_code           = <ls_m2>-DefaultVatCode
      vat_amount         = ls_amt2-vat_amount
      gross_amount       = ls_amt2-gross_amount
      delivery_completed = abap_false
    ) TO lt_items.

    DATA(ls_tot1) = zcl_merp_doc_calc=>calculate_header_totals( lt_calc_items ).
    APPEND VALUE #(
      document_uuid         = lv_hd_uuid1
      document_number       = zcl_merp_format_util=>format_po_code( iv_number = 1 iv_company_code = '1000' )
      document_date         = lv_today
      posting_date          = lv_today
      company_code          = '1000'
      warehouse_code        = zcl_merp_format_util=>format_warehouse_code( 1 )
      business_partner_code = zcl_merp_format_util=>format_bp_code( 1 )
      currency_code         = 'EUR'
      total_net_amount      = ls_tot1-total_net_amount
      total_gross_amount    = ls_tot1-total_gross_amount
      status                = 'N'
      delivery_date         = lv_today + 5
      responsible_person    = 'MUELLER_M'
      remarks               = 'Initial high-volume household goods order'
    ) TO lt_headers.

    " Purchase Order 2 for company 1000
    TRY.
        DATA(lv_hd_uuid2) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_it_uuid3) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_it_uuid4) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
    ENDTRY.

    CLEAR lt_calc_items.

    ASSIGN lt_items_master[ ItemCode = zcl_merp_format_util=>format_item_code( 7 ) ] TO FIELD-SYMBOL(<ls_m7>).

    DATA(ls_amt3) = zcl_merp_doc_calc=>calc_on_qty_price_change(
      iv_quantity       = 3
      iv_price          = '1200.00'
      iv_vat_percentage = CONV decfloat34( <ls_v1>-Percentage ) ).
    APPEND ls_amt3 TO lt_calc_items.

    APPEND VALUE #(
      item_uuid          = lv_it_uuid3
      header_uuid        = lv_hd_uuid2
      item_no            = 10
      item_code          = <ls_m7>-ItemCode
      quantity           = 3
      unit_of_measure    = <ls_m7>-BaseUnitOfMeasure
      currency_code      = 'EUR'
      price              = '1200.00'
      net_amount         = ls_amt3-net_amount
      vat_code           = <ls_m7>-DefaultVatCode
      vat_amount         = ls_amt3-vat_amount
      gross_amount       = ls_amt3-gross_amount
      delivery_completed = abap_false
    ) TO lt_items.

    ASSIGN lt_items_master[ ItemCode = zcl_merp_format_util=>format_item_code( 10 ) ] TO FIELD-SYMBOL(<ls_m10>).

    DATA(ls_amt4) = zcl_merp_doc_calc=>calc_on_qty_price_change(
      iv_quantity       = 5
      iv_price          = '15.00'
      iv_vat_percentage = CONV decfloat34( <ls_v1>-Percentage ) ).
    APPEND ls_amt4 TO lt_calc_items.

    APPEND VALUE #(
      item_uuid          = lv_it_uuid4
      header_uuid        = lv_hd_uuid2
      item_no            = 20
      item_code          = <ls_m10>-ItemCode
      quantity           = 5
      unit_of_measure    = <ls_m10>-BaseUnitOfMeasure
      currency_code      = 'EUR'
      price              = '15.00'
      net_amount         = ls_amt4-net_amount
      vat_code           = <ls_m10>-DefaultVatCode
      vat_amount         = ls_amt4-vat_amount
      gross_amount       = ls_amt4-gross_amount
      delivery_completed = abap_false
    ) TO lt_items.

    DATA(ls_tot2) = zcl_merp_doc_calc=>calculate_header_totals( lt_calc_items ).
    APPEND VALUE #(
      document_uuid         = lv_hd_uuid2
      document_number       = zcl_merp_format_util=>format_po_code( iv_number = 2 iv_company_code = '1000' )
      document_date         = lv_today
      posting_date          = lv_today
      company_code          = '1000'
      warehouse_code        = zcl_merp_format_util=>format_warehouse_code( 2 )
      business_partner_code = zcl_merp_format_util=>format_bp_code( 4 )
      currency_code         = 'EUR'
      total_net_amount      = ls_tot2-total_net_amount
      total_gross_amount    = ls_tot2-total_gross_amount
      status                = 'N'
      delivery_date         = lv_today + 3
      responsible_person    = 'SCHMIDT_A'
      remarks               = 'Electronics stock replenishment'
    ) TO lt_headers.

    " Purchase Order for company 2000
    TRY.
        DATA(lv_hd_uuid3) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_it_uuid5) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
    ENDTRY.

    CLEAR lt_calc_items.

    DATA(ls_amt5) = zcl_merp_doc_calc=>calc_on_qty_price_change(
      iv_quantity       = 4
      iv_price          = '550.00'
      iv_vat_percentage = CONV decfloat34( <ls_v1>-Percentage ) ).
    APPEND ls_amt5 TO lt_calc_items.

    APPEND VALUE #(
      item_uuid          = lv_it_uuid5
      header_uuid        = lv_hd_uuid3
      item_no            = 10
      item_code          = <ls_m1>-ItemCode
      quantity           = 4
      unit_of_measure    = <ls_m1>-BaseUnitOfMeasure
      currency_code      = 'EUR'
      price              = '550.00'
      net_amount         = ls_amt5-net_amount
      vat_code           = <ls_m1>-DefaultVatCode
      vat_amount         = ls_amt5-vat_amount
      gross_amount       = ls_amt5-gross_amount
      delivery_completed = abap_false
    ) TO lt_items.

    DATA(ls_tot3) = zcl_merp_doc_calc=>calculate_header_totals( lt_calc_items ).
    APPEND VALUE #(
      document_uuid         = lv_hd_uuid3
      document_number       = zcl_merp_format_util=>format_po_code( iv_number = 1 iv_company_code = '2000' )
      document_date         = lv_today
      posting_date          = lv_today
      company_code          = '2000'
      warehouse_code        = zcl_merp_format_util=>format_warehouse_code( 5 )
      business_partner_code = zcl_merp_format_util=>format_bp_code( 2 )
      currency_code         = 'EUR'
      total_net_amount      = ls_tot3-total_net_amount
      total_gross_amount    = ls_tot3-total_gross_amount
      status                = 'N'
      delivery_date         = lv_today + 6
      responsible_person    = 'FISCHER_K'
      remarks               = 'Initial trading stock supply'
    ) TO lt_headers.

    " Purchase Order for company 3000
    TRY.
        DATA(lv_hd_uuid4) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_it_uuid6) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
    ENDTRY.

    CLEAR lt_calc_items.

    DATA(ls_amt6) = zcl_merp_doc_calc=>calc_on_qty_price_change(
      iv_quantity       = 2
      iv_price          = '1200.00'
  iv_vat_percentage = CONV decfloat34( <ls_v1>-Percentage ) ).
    APPEND ls_amt6 TO lt_calc_items.
    APPEND VALUE #(
    item_uuid          = lv_it_uuid6
    header_uuid        = lv_hd_uuid4
    item_no            = 10
    item_code          = <ls_m7>-ItemCode
    quantity           = 2
    unit_of_measure    = <ls_m7>-BaseUnitOfMeasure
    currency_code      = 'EUR'
    price              = '1200.00'
    net_amount         = ls_amt6-net_amount
    vat_code           = <ls_m7>-DefaultVatCode
    vat_amount         = ls_amt6-vat_amount
    gross_amount       = ls_amt6-gross_amount
    delivery_completed = abap_false
    ) TO lt_items.
    DATA(ls_tot4) = zcl_merp_doc_calc=>calculate_header_totals( lt_calc_items ).
    APPEND VALUE #(
    document_uuid         = lv_hd_uuid4
    document_number       = zcl_merp_format_util=>format_po_code( iv_number = 1 iv_company_code = '3000' )
    document_date         = lv_today
    posting_date          = lv_today
    company_code          = '3000'
    warehouse_code        = zcl_merp_format_util=>format_warehouse_code( 1 )
    business_partner_code = zcl_merp_format_util=>format_bp_code( 4 )
    currency_code         = 'EUR'
    total_net_amount      = ls_tot4-total_net_amount
    total_gross_amount    = ls_tot4-total_gross_amount
    status                = 'N'
    delivery_date         = lv_today + 4
    responsible_person    = 'WEBER_J'
    remarks               = 'Modevi branch appliance starter set'
    ) TO lt_headers.

    " Write target entities to database
    fill_audit_fields( CHANGING ct_data = lt_headers ).
    INSERT zmerp_po_hdr FROM TABLE @lt_headers.

    write_insert_log( iv_entity_name = 'Purchase Order Header' iv_count = sy-dbcnt out = out ).

    fill_audit_fields( CHANGING ct_data = lt_items ).
    INSERT zmerp_po_itm FROM TABLE @lt_items.
    write_insert_log( iv_entity_name = 'Purchase Order Item' iv_count = sy-dbcnt out = out ).

  ENDMETHOD.

  METHOD clear_table_data.
    DELETE FROM (iv_active_table).
    IF iv_draft_table IS NOT INITIAL.
      DELETE FROM (iv_draft_table).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
