"! Initial seed data for Mini ERP.
"! All data is reset first (ZCL_MERP_CLEAR_ALL_DATA). Master data is inserted directly;
"! documents are created via EML, so all business logic applies (number ranges, defaults,
"! amounts, validations, stock movements, purchase order status).
CLASS zcl_merp_initial_setup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    "! Resets all data and creates master data and documents.
    "! @parameter out | Console output object for logging setup progress
    CLASS-METHODS execute
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! Document line: item number (formatted to the item code), quantity, price (purchase orders only)
    TYPES: BEGIN OF ty_line,
             item_no  TYPE i,
             quantity TYPE zmerp_quantity,
             price    TYPE zmerp_price,
           END OF ty_line,
           tt_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    "! Purchase order definition (dates relative to today)
    TYPES: BEGIN OF ty_po,
             company_code TYPE zmerp_company_code,
             warehouse_no TYPE i,
             partner_no   TYPE i,
             days_ago     TYPE i,
             delivery_in  TYPE i,
             responsible  TYPE zmerp_resp_person,
             remarks      TYPE zmerp_remarks,
             release      TYPE abap_bool,
             lines        TYPE tt_lines,
           END OF ty_po.

    "! Goods receipt definition: lines contain only quantities differing from the open quantity
    TYPES: BEGIN OF ty_gr,
             po_uuid     TYPE sysuuid_x16,
             days_ago    TYPE i,
             responsible TYPE zmerp_resp_person,
             remarks     TYPE zmerp_remarks,
             post        TYPE abap_bool,
             lines       TYPE tt_lines,
           END OF ty_gr.

    TYPES: BEGIN OF ty_quantity,
             item_code TYPE zmerp_item_code,
             quantity  TYPE zmerp_quantity,
           END OF ty_quantity,
           tt_quantities TYPE STANDARD TABLE OF ty_quantity WITH EMPTY KEY.

    TYPES tt_messages TYPE STANDARD TABLE OF REF TO if_abap_behv_message WITH EMPTY KEY.

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

    "! Logs a failed EML step together with its RAP messages.
    CLASS-METHODS write_failure
      IMPORTING
        iv_text     TYPE string
        it_messages TYPE tt_messages
        out         TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates company codes.
    CLASS-METHODS setup_company_codes
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates warehouses.
    CLASS-METHODS setup_warehouses
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates VAT rates.
    CLASS-METHODS setup_vat_rates
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates item groups.
    CLASS-METHODS setup_item_groups
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates items (products and services).
    CLASS-METHODS setup_items
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Populates business partners.
    CLASS-METHODS setup_business_partners
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Creates purchase orders and goods receipts covering the main lifecycle states.
    CLASS-METHODS setup_documents
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Creates a purchase order via EML and optionally releases it.
    "! @parameter is_po      | Purchase order definition
    "! @parameter rv_po_uuid | Key of the created purchase order (initial if it failed)
    CLASS-METHODS create_purchase_order
      IMPORTING
        is_po             TYPE ty_po
        out               TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rv_po_uuid) TYPE sysuuid_x16 .

    "! Creates a goods receipt for a purchase order via EML and optionally posts it.
    "! Items are filled from the open quantities of the purchase order by the goods receipt logic.
    "! @parameter is_gr | Goods receipt definition
    CLASS-METHODS create_goods_receipt
      IMPORTING
        is_gr TYPE ty_gr
        out   TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

ENDCLASS.

CLASS zcl_merp_initial_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    execute( out ).
  ENDMETHOD.

  METHOD execute.
    write_log( iv_text = '=== Starting Initial Data Setup for Mini ERP ===' out = out ).

    " 1. Reset: all tables (master data, documents, stock movements) and number range levels
    zcl_merp_clear_all_data=>execute( out ).

    " 2. Master data
    setup_company_codes( out ).
    setup_vat_rates( out ).
    setup_warehouses( out ).
    setup_item_groups( out ).
    setup_items( out ).
    setup_business_partners( out ).

    " 3. Number range levels follow the inserted master data; document numbers start from the beginning
    zcl_merp_num_range_util=>sync_intervals_from_db( ).

    " Cleanup, master data and number range intervals are saved before documents are created:
    " number assignment (number_get) must not wait for our own uncommitted interval changes
    COMMIT WORK.

    " 4. Documents via EML (the business logic assigns numbers, amounts, stock and statuses)
    setup_documents( out ).

    write_log( iv_text = '==== Initial Data Setup Completed ====' out = out ).
  ENDMETHOD.

  METHOD write_insert_log.
    write_log( iv_text = |[{ iv_entity_name }]: Successfully inserted { iv_count } rows.| out = out ).
  ENDMETHOD.

  METHOD write_failure.
    write_log( iv_text = iv_text out = out ).
    LOOP AT it_messages INTO DATA(lo_message) WHERE table_line IS BOUND.
      write_log( iv_text = |    - { lo_message->if_message~get_text( ) }| out = out ).
    ENDLOOP.
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
    DATA lt_comp_code TYPE zif_merp_constants=>ty_md_comp_tt.

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
    DATA lt_vat_rates TYPE zif_merp_constants=>ty_md_vat_tt.

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
    DATA lt_warehouses TYPE zif_merp_constants=>ty_md_wh_tt.

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
        warehouse_name = 'Altlager Frankfurt'
        company_code   = '1000'
        is_blocked     = abap_true )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 6 )
        warehouse_name = 'Hauptlager Hamburg'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 7 )
        warehouse_name = 'Lager München'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 8 )
        warehouse_name = 'Transitlager Hamburg'
        company_code   = '2000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 9 )
        warehouse_name = 'Hauptlager Kusel'
        company_code   = '3000' )

      ( warehouse_code = zcl_merp_format_util=>format_warehouse_code( 10 )
        warehouse_name = 'Lager Kaiserslautern'
        company_code   = '3000' )
    ).

    fill_audit_fields( CHANGING ct_data = lt_warehouses ).

    INSERT zmerp_warehouse FROM TABLE @lt_warehouses.
    write_insert_log( iv_entity_name = 'Warehouse' iv_count = sy-dbcnt out = out ).
  ENDMETHOD.

  METHOD setup_item_groups.
    DATA(lv_vat19) = zcl_merp_format_util=>format_vat_code( 3 ).
    DATA(lv_vat7)  = zcl_merp_format_util=>format_vat_code( 2 ).

    DATA lt_item_groups TYPE zif_merp_constants=>ty_md_itemgr_tt.

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
    DATA(lv_grp1) = zcl_merp_format_util=>format_item_grp_code( 1 ).
    DATA(lv_grp2) = zcl_merp_format_util=>format_item_grp_code( 2 ).
    DATA(lv_grp3) = zcl_merp_format_util=>format_item_grp_code( 3 ).
    DATA(lv_grp4) = zcl_merp_format_util=>format_item_grp_code( 4 ).
    DATA(lv_grp5) = zcl_merp_format_util=>format_item_grp_code( 5 ).
    DATA(lv_grp6) = zcl_merp_format_util=>format_item_grp_code( 6 ).

    DATA lt_items TYPE zif_merp_constants=>ty_md_item_tt.

    lt_items = VALUE #(
      " Group 1: Major Home Appliances
      ( item_code            = zcl_merp_format_util=>format_item_code( 1 )
        description          = 'Washing Machine Bosch Series 6'
        article              = 'BSH-WM-600'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 2 )
        description          = 'Refrigerator Siemens iQ500'
        article              = 'SIE-RF-500'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 3 )
        description          = 'Dishwasher Miele G7000'
        article              = 'MIE-DW-700'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp1
        base_unit_of_measure = 'EA' )

      " Group 2: Small Kitchen Appliances
      ( item_code            = zcl_merp_format_util=>format_item_code( 4 )
        description          = 'Espresso Machine DeLonghi Magnifica'
        article              = 'DLG-EM-100'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 5 )
        description          = 'Electric Kettle Philips Daily Collection'
        article              = 'PHL-EK-200'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 6 )
        description          = 'Toaster Tefal Express 2-Slot'
        article              = 'TEF-TS-300'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp2
        base_unit_of_measure = 'EA' )

      " Group 3: Consumer Electronics
      ( item_code            = zcl_merp_format_util=>format_item_code( 7 )
        description          = 'Smart TV Samsung 55 Inch OLED'
        article              = 'SAM-TV-55O'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 8 )
        description          = 'Soundbar Sony HT-S400 2.1ch'
        article              = 'SNE-SB-400'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 9 )
        description          = 'Wireless Headphones Bose QuietComfort 45'
        article              = 'BOS-HP-QC45'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp3
        base_unit_of_measure = 'EA' )

      " Group 4: Accessories & Supplies
      ( item_code            = zcl_merp_format_util=>format_item_code( 10 )
        description          = 'HDMI Cable 2.0 High Speed (2m)'
        article              = 'ACC-HDMI-02'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp4
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 11 )
        description          = 'Washing Machine Water Inlet Hose (1.5m)'
        article              = 'ACC-HOSE-15'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp4
        base_unit_of_measure = 'EA' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 12 )
        description          = 'Descaling Solution for Coffee Machines 500ml'
        article              = 'ACC-DESC-50'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp4
        base_unit_of_measure = 'EA' )

      " Group 5: Installation & Support Services
      ( item_code            = zcl_merp_format_util=>format_item_code( 13 )
        description          = 'Home Appliance Installation Service'
        article              = 'SRV-INST-01'
        item_type            = zif_merp_constants=>c_item_type-service
        item_group_code      = lv_grp5
        base_unit_of_measure = 'H' )
      ( item_code            = zcl_merp_format_util=>format_item_code( 14 )
        description          = 'Extended Warranty & On-site Repair Service'
        article              = 'SRV-REPR-02'
        item_type            = zif_merp_constants=>c_item_type-service
        item_group_code      = lv_grp5
        base_unit_of_measure = 'H' )

      " Group 6: Legacy Office Equipment (Blocked)
      ( item_code            = zcl_merp_format_util=>format_item_code( 15 )
        description          = 'Siemens Optipoint 500 Entry'
        article              = 'SIE-TEL-500'
        item_type            = zif_merp_constants=>c_item_type-product
        item_group_code      = lv_grp6
        base_unit_of_measure = 'EA'
        is_blocked           = abap_true )

      ( item_code            = zcl_merp_format_util=>format_item_code( 16 )
        description          = 'Express Delivery and Connection Service'
        article              = 'SRV-DELIV-03'
        item_type            = zif_merp_constants=>c_item_type-service
        item_group_code      = lv_grp5
        base_unit_of_measure = 'EA' )
    ).

    " Default VAT code of each item comes from its item group
    DATA lt_grp_keys TYPE zif_merp_md_item_group_sel=>tt_item_group_keys.
    lt_grp_keys = VALUE #( FOR GROUPS grp OF item IN lt_items GROUP BY item-item_group_code ( ItemGroupCode = grp ) ).

    DATA(lt_item_groups) = NEW zcl_merp_md_item_group_sel( )->zif_merp_md_item_group_sel~read_item_groups( lt_grp_keys ).

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
    DATA lt_bp TYPE zif_merp_constants=>ty_md_bp_tt.

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

  METHOD setup_documents.
    " Readable amounts: every line (also of a partial receipt) has a net amount that is a multiple of 100,
    " so VAT (19% / 7%) and gross amounts have no cents. The only exception is the TV in PO 1:
    " it shows how the last receipt closes the rounding cents of a purchase order item.
    "   PO line 3 x 1199.99 at 19% VAT = 3599.97 net, VAT 683.9943 -> 683.99
    "   GR 1:  2 TVs                   = 2399.98 net, VAT 455.9962 -> 456.00
    "   GR 2:  last TV                 = 1199.99 net, VAT 227.9981 -> 228.00 by calculation,
    "                                    but takes the open VAT 683.99 - 456.00 = 227.99 -> PO item closed to 0.00
    " Units: EA for goods, H for services charged by the hour (units of the SAP standard).

    " PO 1 (1000, Samsung): received completely by two goods receipts -> 'Completed'
    DATA(lv_po1) = create_purchase_order(
      is_po = VALUE #( company_code = '1000' warehouse_no = 1 partner_no = 4
                       days_ago     = 3      delivery_in  = 2
                       responsible  = 'SCHMIDT_A'
                       remarks      = 'TV season stock'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 7  quantity = 3  price = '1199.99' )
                                               ( item_no = 10 quantity = 10 price = '10.00' )
                                               ( item_no = 14 quantity = 3  price = '100.00' ) ) )
      out   = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po1
                       days_ago    = 1
                       responsible = 'SCHMIDT_A'
                       remarks     = 'Delivery 1 of 2: 1 TV with warranty follows'
                       post        = abap_true
                       lines       = VALUE #( ( item_no = 7  quantity = 2 )
                                              ( item_no = 14 quantity = 2 ) ) )
      out   = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po1
                       days_ago    = 0
                       responsible = 'SCHMIDT_A'
                       remarks     = 'Delivery 2 of 2: last TV with warranty closes the cents'
                       post        = abap_true )
      out   = out ).

    " PO 2 (1000, Bosch): partially received -> 'In Delivery' (2 washing machines and 2 h installation open)
    DATA(lv_po2) = create_purchase_order(
      is_po = VALUE #( company_code = '1000' warehouse_no = 2 partner_no = 1
                       days_ago     = 2      delivery_in  = 5
                       responsible  = 'MUELLER_M'
                       remarks      = 'Large appliances with installation'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 1  quantity = 5  price = '500.00' )
                                               ( item_no = 2  quantity = 2  price = '800.00' )
                                               ( item_no = 11 quantity = 10 price = '10.00' )
                                               ( item_no = 13 quantity = 4  price = '50.00' ) ) )
      out   = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po2
                       days_ago    = 0
                       responsible = 'MUELLER_M'
                       remarks     = 'Partial delivery: 2 washing machines and 2 h installation open'
                       post        = abap_true
                       lines       = VALUE #( ( item_no = 1  quantity = 3 )
                                              ( item_no = 13 quantity = 2 ) ) )
      out   = out ).

    " PO 3 (1000, DeLonghi): released; the goods receipt is prepared but not posted yet
    "   -> purchase order 'Approved', goods receipt 'New'
    DATA(lv_po3) = create_purchase_order(
      is_po = VALUE #( company_code = '1000' warehouse_no = 1 partner_no = 3
                       days_ago     = 1      delivery_in  = 4
                       responsible  = 'MUELLER_M'
                       remarks      = 'Coffee machines and supplies'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 4  quantity = 4  price = '400.00' )
                                               ( item_no = 12 quantity = 10 price = '10.00' )
                                               ( item_no = 5  quantity = 10 price = '30.00' )
                                               ( item_no = 16 quantity = 1  price = '100.00' ) ) )
      out   = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po3
                       days_ago    = 0
                       responsible = 'MUELLER_M'
                       remarks     = 'Goods arrived, receipt to be checked and posted'
                       post        = abap_false )
      out   = out ).

    " PO 4 (2000, Conrad): released, nothing received -> 'Approved'
    create_purchase_order(
      is_po = VALUE #( company_code = '2000' warehouse_no = 6 partner_no = 12
                       days_ago     = 2      delivery_in  = 6
                       responsible  = 'FISCHER_K'
                       remarks      = 'Audio assortment for Hamburg'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 9  quantity = 10 price = '300.00' )
                                               ( item_no = 8  quantity = 4  price = '250.00' )
                                               ( item_no = 10 quantity = 20 price = '10.00' )
                                               ( item_no = 16 quantity = 1  price = '100.00' ) ) )
      out   = out ).

    " PO 5 (2000, Sony): received completely by one goods receipt -> 'Completed' (stock in Munich)
    DATA(lv_po5) = create_purchase_order(
      is_po = VALUE #( company_code = '2000' warehouse_no = 7 partner_no = 5
                       days_ago     = 4      delivery_in  = 1
                       responsible  = 'FISCHER_K'
                       remarks      = 'Audio stock for Munich'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 8 quantity = 6 price = '250.00' )
                                               ( item_no = 9 quantity = 5 price = '300.00' ) ) )
      out   = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po5
                       days_ago    = 1
                       responsible = 'FISCHER_K'
                       remarks     = 'Complete delivery'
                       post        = abap_true )
      out   = out ).

    " PO 6 (3000, ElectronicPartner): not released -> 'New'
    create_purchase_order(
      is_po = VALUE #( company_code = '3000' warehouse_no = 9 partner_no = 11
                       days_ago     = 1      delivery_in  = 7
                       responsible  = 'WEBER_J'
                       remarks      = 'Modevi starter set, waiting for approval'
                       release      = abap_false
                       lines        = VALUE #( ( item_no = 6 quantity = 10 price = '40.00' )
                                               ( item_no = 5 quantity = 10 price = '30.00' ) ) )
      out   = out ).

    " Summary: resulting purchase order statuses
    SELECT document_number, status
      FROM zmerp_po_hdr
      ORDER BY document_number
      INTO TABLE @DATA(lt_po_status).

    write_log( iv_text = '[Summary] Purchase order statuses:' out = out ).
    LOOP AT lt_po_status REFERENCE INTO DATA(lr_po_status).
      write_log( iv_text = |    { lr_po_status->document_number }: { lr_po_status->status }| out = out ).
    ENDLOOP.
  ENDMETHOD.

  METHOD create_purchase_order.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    " 1. Header and items: currency, item defaults and amounts are derived by the purchase order logic
    MODIFY ENTITIES OF zmerp_r_purchaseorder
      ENTITY PurchaseOrder
        CREATE FIELDS ( CompanyCode WarehouseCode BusinessPartnerCode DocumentDate DeliveryDate
                        ResponsiblePerson Remarks )
        WITH VALUE #( ( %cid                = 'PO'
                        CompanyCode         = is_po-company_code
                        WarehouseCode       = zcl_merp_format_util=>format_warehouse_code( is_po-warehouse_no )
                        BusinessPartnerCode = zcl_merp_format_util=>format_bp_code( is_po-partner_no )
                        DocumentDate        = CONV d( lv_today - is_po-days_ago )
                        DeliveryDate        = CONV d( lv_today + is_po-delivery_in )
                        ResponsiblePerson   = is_po-responsible
                        Remarks             = is_po-remarks ) )
        CREATE BY \_Items
        FIELDS ( ItemCode Quantity Price )
        WITH VALUE #( ( %cid_ref = 'PO'
                        %target  = VALUE #( FOR po_line IN is_po-lines INDEX INTO lv_index
                                            ( %cid     = |PO_ITEM_{ lv_index }|
                                              ItemCode = zcl_merp_format_util=>format_item_code( po_line-item_no )
                                              Quantity = po_line-quantity
                                              Price    = po_line-price ) ) ) )
      MAPPED DATA(ls_mapped).

    rv_po_uuid = VALUE #( ls_mapped-purchaseorder[ 1 ]-DocumentUUID OPTIONAL ).

    COMMIT ENTITIES RESPONSE OF zmerp_r_purchaseorder
      FAILED DATA(ls_save_failed)
      REPORTED DATA(ls_save_reported).

    IF ls_save_failed IS NOT INITIAL OR rv_po_uuid IS INITIAL.
      write_failure(
        iv_text     = |[Purchase Order]: Creation for company { is_po-company_code } failed:|
        it_messages = VALUE #( BASE VALUE #( FOR save_hdr IN ls_save_reported-purchaseorder ( save_hdr-%msg ) )
                               FOR save_itm IN ls_save_reported-purchaseorderitem ( save_itm-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      CLEAR rv_po_uuid.
      RETURN.
    ENDIF.

    " 2. Release ('New' -> 'Approved')
    IF is_po-release = abap_true.
      MODIFY ENTITIES OF zmerp_r_purchaseorder
        ENTITY PurchaseOrder
        EXECUTE releaseDocument
        FROM VALUE #( ( DocumentUUID = rv_po_uuid ) )
        FAILED DATA(ls_release_failed)
        REPORTED DATA(ls_release_reported).

      IF ls_release_failed IS INITIAL.
        COMMIT ENTITIES RESPONSE OF zmerp_r_purchaseorder
          FAILED DATA(ls_commit_failed)
          REPORTED DATA(ls_commit_reported).
      ENDIF.

      IF ls_release_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
        write_failure(
          iv_text     = |[Purchase Order]: Release for company { is_po-company_code } failed:|
          it_messages = VALUE #( BASE VALUE #( FOR rel_hdr IN ls_release_reported-purchaseorder ( rel_hdr-%msg ) )
                                 FOR com_hdr IN ls_commit_reported-purchaseorder ( com_hdr-%msg ) )
          out         = out ).
        ROLLBACK ENTITIES.
      ENDIF.
    ENDIF.

    SELECT SINGLE document_number, status
      FROM zmerp_po_hdr
      WHERE document_uuid = @rv_po_uuid
      INTO @DATA(ls_po).

    write_log( iv_text = |[Purchase Order]: { ls_po-document_number } created, status { ls_po-status }.| out = out ).
  ENDMETHOD.

  METHOD create_goods_receipt.
    IF is_gr-po_uuid IS INITIAL.
      write_log( iv_text = '[Goods Receipt]: Skipped, the purchase order was not created.' out = out ).
      RETURN.
    ENDIF.

    DATA(lv_date) = CONV d( cl_abap_context_info=>get_system_date( ) - is_gr-days_ago ).

    " 1. Header with the purchase order reference: header fields and items (open quantities)
    "    are derived by the goods receipt logic (deriveDocFromPurchaseOrder)
    MODIFY ENTITIES OF zmerp_r_goodsreceipt
      ENTITY GoodsReceipt
      CREATE FIELDS ( PoReferenceUUID DocumentDate PostingDate ResponsiblePerson Remarks )
      WITH VALUE #( ( %cid              = 'GR'
                      PoReferenceUUID   = is_gr-po_uuid
                      DocumentDate      = lv_date
                      PostingDate       = lv_date
                      ResponsiblePerson = is_gr-responsible
                      Remarks           = is_gr-remarks ) )
      MAPPED DATA(ls_mapped).

    DATA(lv_gr_uuid) = VALUE #( ls_mapped-goodsreceipt[ 1 ]-DocumentUUID OPTIONAL ).

    " 2. Partial receipt: the listed items get the given quantity, all others keep the open quantity
    IF is_gr-lines IS NOT INITIAL AND lv_gr_uuid IS NOT INITIAL.
      DATA(lt_quantities) = VALUE tt_quantities(
        FOR gr_line IN is_gr-lines ( item_code = zcl_merp_format_util=>format_item_code( gr_line-item_no )
                                     quantity  = gr_line-quantity ) ).

      READ ENTITIES OF zmerp_r_goodsreceipt
        ENTITY GoodsReceipt BY \_Items
        FIELDS ( ItemCode )
        WITH VALUE #( ( DocumentUUID = lv_gr_uuid ) )
        RESULT DATA(lt_items).

      MODIFY ENTITIES OF zmerp_r_goodsreceipt
        ENTITY GoodsReceiptItem
        UPDATE FIELDS ( Quantity )
        WITH VALUE #( FOR gr_item IN lt_items
                      FOR qty IN lt_quantities WHERE ( item_code = gr_item-ItemCode )
                      ( %tky     = gr_item-%tky
                        Quantity = qty-quantity ) ).
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zmerp_r_goodsreceipt
      FAILED DATA(ls_save_failed)
      REPORTED DATA(ls_save_reported).

    IF ls_save_failed IS NOT INITIAL OR lv_gr_uuid IS INITIAL.
      write_failure(
        iv_text     = '[Goods Receipt]: Saving failed:'
        it_messages = VALUE #( BASE VALUE #( FOR save_hdr IN ls_save_reported-goodsreceipt ( save_hdr-%msg ) )
                               FOR save_itm IN ls_save_reported-goodsreceiptitem ( save_itm-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    " 3. Posting: stock movements and the purchase order status follow the goods receipt logic
    IF is_gr-post = abap_true.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt
        ENTITY GoodsReceipt
        EXECUTE postDocument
        FROM VALUE #( ( DocumentUUID = lv_gr_uuid ) )
        FAILED DATA(ls_post_failed)
        REPORTED DATA(ls_post_reported).

      IF ls_post_failed IS INITIAL.
        COMMIT ENTITIES RESPONSE OF zmerp_r_goodsreceipt
          FAILED DATA(ls_commit_failed)
          REPORTED DATA(ls_commit_reported).
      ENDIF.

      IF ls_post_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
        write_failure(
          iv_text     = '[Goods Receipt]: Posting failed:'
          it_messages = VALUE #( BASE VALUE #( BASE VALUE #( FOR post_hdr IN ls_post_reported-goodsreceipt ( post_hdr-%msg ) )
                                               FOR post_itm IN ls_post_reported-goodsreceiptitem ( post_itm-%msg ) )
                                 FOR com_hdr IN ls_commit_reported-goodsreceipt ( com_hdr-%msg ) )
          out         = out ).
        ROLLBACK ENTITIES.
      ENDIF.
    ENDIF.

    SELECT SINGLE gr~document_number, gr~status, po~document_number AS po_number, po~status AS po_status
      FROM zmerp_gr_hdr AS gr
      INNER JOIN zmerp_po_hdr AS po ON po~document_uuid = gr~po_reference_uuid
      WHERE gr~document_uuid = @lv_gr_uuid
      INTO @DATA(ls_gr).

    write_log( iv_text = |[Goods Receipt]: { ls_gr-document_number } for PO { ls_gr-po_number } created, | &&
                         |status { ls_gr-status }; PO status { ls_gr-po_status }.|
               out     = out ).
  ENDMETHOD.

ENDCLASS.

