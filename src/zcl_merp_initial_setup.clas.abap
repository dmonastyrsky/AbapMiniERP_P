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

    " Dynamically sync NRO levels with real DB record counts
    zcl_merp_num_range_util=>sync_intervals_from_db( ).

    write_log( iv_text = '=== Initial Data Setup Completed Successfully ===' out = out ).
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


  METHOD write_log.
    IF out IS BOUND.
      out->write( iv_text ).
    ENDIF.
  ENDMETHOD.


  METHOD write_insert_log.
    write_log(
      iv_text = |[{ iv_entity_name }]: Successfully inserted { iv_count } rows.|
      out     = out
    ).
  ENDMETHOD.


  METHOD clear_table_data.
    DELETE FROM (iv_active_table).
    IF iv_draft_table IS NOT INITIAL.
      DELETE FROM (iv_draft_table).
    ENDIF.
  ENDMETHOD.


  METHOD setup_company_codes.
    clear_table_data( iv_active_table = CONV tabname( zif_merp_constants=>c_comp-table_db ) ).

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
      ( vat_code    = zcl_merp_num_range_util=>format_vat_code( 1 )
        description = 'VAT 0%'
        percentage  = '0.00' )

      ( vat_code    = zcl_merp_num_range_util=>format_vat_code( 2 )
        description = 'VAT 7%'
        percentage  = '7.00' )

      ( vat_code    = zcl_merp_num_range_util=>format_vat_code( 3 )
        description = 'VAT 19%'
        percentage  = '19.00' )
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
      ( warehouse_code = zcl_merp_num_range_util=>format_warehouse_code( 1 )
        warehouse_name = 'Hauptlager Kusel'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_num_range_util=>format_warehouse_code( 2 )
        warehouse_name = 'Hauptlager Frankfurt'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_num_range_util=>format_warehouse_code( 3 )
        warehouse_name = 'Lager Berlin'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_num_range_util=>format_warehouse_code( 4 )
        warehouse_name = 'Retourlager Frankfurt'
        company_code   = '1000' )

      ( warehouse_code = zcl_merp_num_range_util=>format_warehouse_code( 5 )
        warehouse_name = 'Hauptlager Hamburg'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_num_range_util=>format_warehouse_code( 6 )
        warehouse_name = 'Lager München'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_num_range_util=>format_warehouse_code( 7 )
        warehouse_name = 'Transitlager Hamburg'
        company_code   = '2000' )
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

    DATA(lv_vat19) = zcl_merp_num_range_util=>format_vat_code( 3 ).
    DATA(lv_vat7)  = zcl_merp_num_range_util=>format_vat_code( 2 ).

    DATA lt_item_groups TYPE TABLE OF zmerp_item_group.

    lt_item_groups = VALUE #(
      ( item_group_code  = zcl_merp_num_range_util=>format_item_grp_code( 1 )
        description      = 'Major Home Appliances'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_num_range_util=>format_item_grp_code( 2 )
        description      = 'Small Kitchen Appliances'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_num_range_util=>format_item_grp_code( 3 )
        description      = 'Consumer Electronics'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_num_range_util=>format_item_grp_code( 4 )
        description      = 'Accessories & Supplies'
        default_vat_code = lv_vat19 )

      ( item_group_code  = zcl_merp_num_range_util=>format_item_grp_code( 5 )
        description      = 'Installation & Support Services'
        default_vat_code = lv_vat7 )
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
    DATA(lv_grp1) = zcl_merp_num_range_util=>format_item_grp_code( 1 ).
    DATA(lv_grp2) = zcl_merp_num_range_util=>format_item_grp_code( 2 ).
    DATA(lv_grp3) = zcl_merp_num_range_util=>format_item_grp_code( 3 ).
    DATA(lv_grp4) = zcl_merp_num_range_util=>format_item_grp_code( 4 ).
    DATA(lv_grp5) = zcl_merp_num_range_util=>format_item_grp_code( 5 ).

    DATA lt_items TYPE TABLE OF zmerp_item.

    lt_items = VALUE #(
      " Group 1: Major Home Appliances
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 1 )
        description          = 'Washing Machine Bosch Series 6'
        article              = 'BSH-WM-600'
        item_type            = 'P'
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 2 )
        description          = 'Refrigerator Siemens iQ500'
        article              = 'SIE-RF-500'
        item_type            = 'P'
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 3 )
        description          = 'Dishwasher Miele G7000'
        article              = 'MIE-DW-700'
        item_type            = 'P'
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )

      " Group 2: Small Kitchen Appliances
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 4 )
        description          = 'Espresso Machine DeLonghi Magnifica'
        article              = 'DLG-EM-100'
        item_type            = 'P'
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 5 )
        description          = 'Electric Kettle Philips Daily Collection'
        article              = 'PHL-EK-200'
        item_type            = 'P'
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 6 )
        description          = 'Toaster Tefal Express 2-Slot'
        article              = 'TEF-TS-300'
        item_type            = 'P'
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )

      " Group 3: Consumer Electronics
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 7 )
        description          = 'Smart TV Samsung 55 Inch OLED'
        article              = 'SAM-TV-55O'
        item_type            = 'P'
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 8 )
        description          = 'Soundbar Sony HT-S400 2.1ch'
        article              = 'SNE-SB-400'
        item_type            = 'P'
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 9 )
        description          = 'Wireless Headphones Bose QuietComfort 45'
        article              = 'BOS-HP-QC45'
        item_type            = 'P'
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )

      " Group 4: Accessories & Supplies
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 10 )
        description          = 'HDMI Cable 2.0 High Speed (2m)'
        article              = 'ACC-HDMI-02'
        item_type            = 'P'
        item_group_code      = lv_grp4
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 11 )
        description          = 'Washing Machine Water Inlet Hose (1.5m)'
        article              = 'ACC-HOSE-15'
        item_type            = 'P'
        item_group_code      = lv_grp4
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 12 )
        description          = 'Descaling Solution for Coffee Machines 500ml'
        article              = 'ACC-DESC-50'
        item_type            = 'P'
        item_group_code      = lv_grp4
        base_unit_of_measure = 'BOT' )

      " Group 5: Installation & Support Services
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 13 )
        description          = 'Home Appliance Installation Service'
        article              = 'SRV-INST-01'
        item_type            = 'S'
        item_group_code      = lv_grp5
        base_unit_of_measure = 'H' )
      ( item_code            = zcl_merp_num_range_util=>format_item_code( 14 )
        description          = 'Extended Warranty & On-site Repair Service'
        article              = 'SRV-REPR-02'
        item_type            = 'S'
        item_group_code      = lv_grp5
        base_unit_of_measure = 'H' )
    ).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      lr_item->default_vat_code = zcl_merp_md_util=>get_item_group_default_vat( lr_item->item_group_code ).
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
      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 1 )
        partner_name = 'Bosch-Siemens Hausgeräte GmbH'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE129323400'
        address      = 'Carl-Wery-Straße 34'
        city         = 'München'
        country      = 'DE'
        phone        = '+49 89 459001'
        email        = 'contact@bshg.com' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 2 )
        partner_name = 'Miele & Cie. KG'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE126788901'
        address      = 'Carl-Miele-Straße 29'
        city         = 'Gütersloh'
        country      = 'DE'
        phone        = '+49 5241 890'
        email        = 'info@miele.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 3 )
        partner_name = 'DeLonghi Deutschland GmbH'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE811234567'
        address      = 'Carl-Ulrich-Straße 4'
        city         = 'Neu-Isenburg'
        country      = 'DE'
        phone        = '+49 6102 5990'
        email        = 'service@delonghi.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 4 )
        partner_name = 'Samsung Electronics GmbH'
        is_customer  = abap_false
        is_supplier  = abap_true
        tax_number   = 'DE113546789'
        address      = 'Am Kronberger Hang 6'
        city         = 'Schwalbach am Taunus'
        country      = 'DE'
        phone        = '+49 6196 660'
        email        = 'info@samsung.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 5 )
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
      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 6 )
        partner_name = 'Media-Saturn Retail Group GmbH'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE130123456'
        address      = 'Media-Saturn-Str. 1'
        city         = 'Ingolstadt'
        country      = 'DE'
        phone        = '+49 841 6340'
        email        = 'einkauf@mediamarkt.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 7 )
        partner_name = 'Expert SE'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE115678123'
        address      = 'Bayernstraße 4'
        city         = 'Langenhagen'
        country      = 'DE'
        phone        = '+49 511 78080'
        email        = 'zentrale@expert.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 8 )
        partner_name = 'Euronics Deutschland eG'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE147890123'
        address      = 'Berliner Straße 11'
        city         = 'Ditzingen'
        country      = 'DE'
        phone        = '+49 7156 9280'
        email        = 'info@euronics.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 9 )
        partner_name = 'Elektro-Service Müller GmbH'
        is_customer  = abap_true
        is_supplier  = abap_false
        tax_number   = 'DE289012345'
        address      = 'Trierer Straße 12'
        city         = 'Kusel'
        country      = 'DE'
        phone        = '+49 6381 1234'
        email        = 'service@elektro-mueller.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 10 )
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
      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 11 )
        partner_name = 'ElectronicPartner GmbH & Co. KG'
        is_customer  = abap_true
        is_supplier  = abap_true
        tax_number   = 'DE119345678'
        address      = 'Mündelheimer Weg 40'
        city         = 'Düsseldorf'
        country      = 'DE'
        phone        = '+49 211 41560'
        email        = 'partner@electronicpartner.de' )

      ( partner_code = zcl_merp_num_range_util=>format_bp_code( 12 )
        partner_name = 'Conrad Electronic SE'
        is_customer  = abap_true
        is_supplier  = abap_true
        tax_number   = 'DE133123789'
        address      = 'Klaus-Conrad-Straße 1'
        city         = 'Hirschau'
        country      = 'DE'
        phone        = '+49 9622 300'
        email        = 'b2b@conrad.de' )
    ).

    fill_audit_fields( CHANGING ct_data = lt_bp ).

    INSERT zmerp_bus_part FROM TABLE @lt_bp.
    write_insert_log( iv_entity_name = 'Business Partner' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

ENDCLASS.
