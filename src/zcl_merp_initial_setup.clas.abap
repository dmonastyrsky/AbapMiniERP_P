"! Initial seed data for Mini ERP.
"! All data is reset first (ZCL_MERP_CLEAR_ALL_DATA). Master data and documents are created via EML,
"! so all business logic applies: numbering, defaults, validations, document intervals of new companies,
"! amounts, stock movements and purchase order status. The seed stops when master data cannot be created.
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
    "! Codes of the created master data in seed order: line n is the code of record n
    "! (documents refer to master data by these numbers, e.g. warehouse_no = 1)
    TYPES: BEGIN OF ty_codes,
             companies   TYPE string_table,
             vat_rates   TYPE string_table,
             item_groups TYPE string_table,
             warehouses  TYPE string_table,
             items       TYPE string_table,
             partners    TYPE string_table,
           END OF ty_codes.

    "! Document line: item number (seed order), quantity, price (purchase orders only)
    TYPES: BEGIN OF ty_line,
             item_no  TYPE i,
             quantity TYPE zmerp_quantity,
             price    TYPE zmerp_price,
           END OF ty_line,
           tt_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    "! Purchase order definition (master data by seed order, dates relative to today)
    TYPES: BEGIN OF ty_po,
             company_no   TYPE i,
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

    "! Writes a text line to the console runner if bound.
    CLASS-METHODS write_log
      IMPORTING
        iv_text TYPE string
        out     TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Logs a failed EML step together with its RAP messages.
    CLASS-METHODS write_failure
      IMPORTING
        iv_text     TYPE string
        it_messages TYPE tt_messages
        out         TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Returns the code of record n of a master data list (initial if there is no such record).
    CLASS-METHODS get_code
      IMPORTING
        it_codes       TYPE string_table
        iv_no          TYPE i
      RETURNING
        VALUE(rv_code) TYPE string .

    "! Creates the company codes; each new company gets its document intervals (company saver).
    "! @parameter rt_codes | Company codes in seed order (initial if the creation failed)
    CLASS-METHODS create_company_codes
      IMPORTING
        out             TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table .

    "! Creates the VAT rates.
    "! @parameter rt_codes | VAT codes in seed order (initial if the creation failed)
    CLASS-METHODS create_vat_rates
      IMPORTING
        out             TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table .

    "! Creates the item groups with their default VAT codes.
    "! @parameter rt_codes | Item group codes in seed order (initial if the creation failed)
    CLASS-METHODS create_item_groups
      IMPORTING
        is_codes        TYPE ty_codes
        out             TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table .

    "! Creates the warehouses of the companies.
    "! @parameter rt_codes | Warehouse codes in seed order (initial if the creation failed)
    CLASS-METHODS create_warehouses
      IMPORTING
        is_codes        TYPE ty_codes
        out             TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table .

    "! Creates the items (products and services).
    "! @parameter rt_codes | Item codes in seed order (initial if the creation failed)
    CLASS-METHODS create_items
      IMPORTING
        is_codes        TYPE ty_codes
        out             TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table .

    "! Creates the business partners (suppliers, customers, both).
    "! @parameter rt_codes | Partner codes in seed order (initial if the creation failed)
    CLASS-METHODS create_business_partners
      IMPORTING
        out             TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table .

    "! Creates all master data via EML, level by level, and aligns the master data intervals.
    "! @parameter rs_codes | Codes of the created master data (initial if a level failed)
    CLASS-METHODS setup_master_data
      IMPORTING
        out             TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rs_codes) TYPE ty_codes .

    "! Creates purchase orders and goods receipts covering the main lifecycle states.
    CLASS-METHODS setup_documents
      IMPORTING
        is_codes TYPE ty_codes
        out      TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

    "! Creates a purchase order via EML and optionally releases it.
    "! @parameter is_po      | Purchase order definition
    "! @parameter rv_po_uuid | Key of the created purchase order (initial if it failed)
    CLASS-METHODS create_purchase_order
      IMPORTING
        is_codes          TYPE ty_codes
        is_po             TYPE ty_po
        out               TYPE REF TO if_oo_adt_classrun_out OPTIONAL
      RETURNING
        VALUE(rv_po_uuid) TYPE sysuuid_x16 .

    "! Creates a goods receipt for a purchase order via EML and optionally posts it.
    "! Items are filled from the open quantities of the purchase order by the goods receipt logic.
    "! @parameter is_gr | Goods receipt definition
    CLASS-METHODS create_goods_receipt
      IMPORTING
        is_codes TYPE ty_codes
        is_gr    TYPE ty_gr
        out      TYPE REF TO if_oo_adt_classrun_out OPTIONAL .

ENDCLASS.



CLASS zcl_merp_initial_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    execute( out ).
  ENDMETHOD.

  METHOD execute.
    write_log( iv_text = '=== Starting Initial Data Setup for Mini ERP ===' out = out ).

    " 1. Reset: all tables (master data, documents, stock movements) and number range levels.
    "    Committed before EML: number assignment (number_get) must not wait for our own
    "    uncommitted interval changes
    zcl_merp_clear_all_data=>execute( out ).
    COMMIT WORK.

    " 2. Master data via EML
    DATA(ls_codes) = setup_master_data( out ).
    IF ls_codes IS INITIAL.
      write_log( iv_text = '=== Initial Data Setup stopped ===' out = out ).
      RETURN.
    ENDIF.

    " 3. Documents via EML (the business logic assigns numbers, amounts, stock and statuses)
    setup_documents( is_codes = ls_codes out = out ).

    write_log( iv_text = '==== Initial Data Setup Completed ====' out = out ).
  ENDMETHOD.

  METHOD write_failure.
    write_log( iv_text = iv_text out = out ).
    LOOP AT it_messages INTO DATA(lo_message) WHERE table_line IS BOUND.
      write_log( iv_text = |    - { lo_message->if_message~get_text( ) }| out = out ).
    ENDLOOP.
  ENDMETHOD.

  METHOD write_log.
    IF out IS BOUND.
      out->write( iv_text ).
    ENDIF.
  ENDMETHOD.

  METHOD get_code.
    rv_code = VALUE #( it_codes[ iv_no ] OPTIONAL ).
  ENDMETHOD.

  METHOD create_company_codes.
    TYPES tt_create TYPE TABLE FOR CREATE zmerp_r_company_code.

    " Company codes are entered manually (no number range)
    DATA(lt_create) = VALUE tt_create(
      ( CompanyCode   = '1000'
        CompanyName   = 'MERP Deutschland GmbH'
        CompanyPrefix = 'DE'
        CurrencyCode  = 'EUR'
        Country       = 'DE' )

      ( CompanyCode   = '2000'
        CompanyName   = 'MERP Trading GmbH'
        CompanyPrefix = 'TR'
        CurrencyCode  = 'EUR'
        Country       = 'DE' )

      ( CompanyCode   = '3000'
        CompanyName   = 'Modevi GmbH'
        CompanyPrefix = 'MD'
        CurrencyCode  = 'EUR'
        Country       = 'DE' )

      ( CompanyCode   = '4000'
        CompanyName   = 'MERP Inactive Services GmbH'
        CompanyPrefix = 'IS'
        CurrencyCode  = 'EUR'
        Country       = 'DE'
        IsBlocked     = abap_true )
    ).

    LOOP AT lt_create ASSIGNING FIELD-SYMBOL(<ls_create>).
      <ls_create>-%cid = |COMPANY_{ sy-tabix }|.
    ENDLOOP.

    MODIFY ENTITIES OF zmerp_r_company_code
      ENTITY CompanyCode
      CREATE FIELDS ( CompanyCode CompanyName CompanyPrefix CurrencyCode Country IsBlocked )
      WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zmerp_r_company_code
        FAILED DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
    ENDIF.

    IF ls_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
      write_failure(
        iv_text     = '[Company Code]: Creation failed:'
        it_messages = VALUE #( BASE VALUE #( FOR rep IN ls_reported-companycode ( rep-%msg ) )
                               FOR com IN ls_commit_reported-companycode ( com-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    rt_codes = VALUE #( FOR row IN lt_create ( CONV #( ls_mapped-companycode[ %cid = row-%cid ]-CompanyCode ) ) ).
    write_log( iv_text = |[Company Code]: { lines( rt_codes ) } records created.| out = out ).
  ENDMETHOD.

  METHOD create_vat_rates.
    TYPES tt_create TYPE TABLE FOR CREATE zmerp_r_vat_rate.

    " VAT codes come from the number range (early numbering)
    DATA(lt_create) = VALUE tt_create(
      ( Description = 'VAT 0%'
        Percentage  = '0.00' )

      ( Description = 'VAT 7%'
        Percentage  = '7.00' )

      ( Description = 'VAT 19%'
        Percentage  = '19.00' )

      ( Description = 'VAT 16% (Historical)'
        Percentage  = '16.00'
        IsBlocked   = abap_true )
    ).

    LOOP AT lt_create ASSIGNING FIELD-SYMBOL(<ls_create>).
      <ls_create>-%cid = |VAT_{ sy-tabix }|.
    ENDLOOP.

    MODIFY ENTITIES OF zmerp_r_vat_rate
      ENTITY VatRate
      CREATE FIELDS ( Description Percentage IsBlocked )
      WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zmerp_r_vat_rate
        FAILED DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
    ENDIF.

    IF ls_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
      write_failure(
        iv_text     = '[VAT Rate]: Creation failed:'
        it_messages = VALUE #( BASE VALUE #( FOR rep IN ls_reported-vatrate ( rep-%msg ) )
                               FOR com IN ls_commit_reported-vatrate ( com-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    rt_codes = VALUE #( FOR row IN lt_create ( CONV #( ls_mapped-vatrate[ %cid = row-%cid ]-VatCode ) ) ).
    write_log( iv_text = |[VAT Rate]: { lines( rt_codes ) } records created.| out = out ).
  ENDMETHOD.

  METHOD create_item_groups.
    TYPES tt_create TYPE TABLE FOR CREATE zmerp_r_item_group.

    DATA(lv_vat7)  = get_code( it_codes = is_codes-vat_rates iv_no = 2 ).
    DATA(lv_vat19) = get_code( it_codes = is_codes-vat_rates iv_no = 3 ).

    DATA(lt_create) = VALUE tt_create(
      ( Description    = 'Major Home Appliances'
        DefaultVatCode = lv_vat19 )

      ( Description    = 'Small Kitchen Appliances'
        DefaultVatCode = lv_vat19 )

      ( Description    = 'Consumer Electronics'
        DefaultVatCode = lv_vat19 )

      ( Description    = 'Accessories & Supplies'
        DefaultVatCode = lv_vat19 )

      ( Description    = 'Installation & Support Services'
        DefaultVatCode = lv_vat7 )

      ( Description    = 'Legacy Office Equipment'
        DefaultVatCode = lv_vat19
        IsBlocked      = abap_true )
    ).

    LOOP AT lt_create ASSIGNING FIELD-SYMBOL(<ls_create>).
      <ls_create>-%cid = |ITEM_GROUP_{ sy-tabix }|.
    ENDLOOP.

    MODIFY ENTITIES OF zmerp_r_item_group
      ENTITY ItemGroup
      CREATE FIELDS ( Description DefaultVatCode IsBlocked )
      WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zmerp_r_item_group
        FAILED DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
    ENDIF.

    IF ls_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
      write_failure(
        iv_text     = '[Item Group]: Creation failed:'
        it_messages = VALUE #( BASE VALUE #( FOR rep IN ls_reported-itemgroup ( rep-%msg ) )
                               FOR com IN ls_commit_reported-itemgroup ( com-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    rt_codes = VALUE #( FOR row IN lt_create ( CONV #( ls_mapped-itemgroup[ %cid = row-%cid ]-ItemGroupCode ) ) ).
    write_log( iv_text = |[Item Group]: { lines( rt_codes ) } records created.| out = out ).
  ENDMETHOD.

  METHOD create_warehouses.
    TYPES tt_create TYPE TABLE FOR CREATE zmerp_r_warehouse.

    DATA(lv_company1) = get_code( it_codes = is_codes-companies iv_no = 1 ).
    DATA(lv_company2) = get_code( it_codes = is_codes-companies iv_no = 2 ).
    DATA(lv_company3) = get_code( it_codes = is_codes-companies iv_no = 3 ).

    DATA(lt_create) = VALUE tt_create(
      ( WarehouseName = 'Hauptlager Kusel'
        CompanyCode   = lv_company1 )

      ( WarehouseName = 'Hauptlager Frankfurt'
        CompanyCode   = lv_company1 )

      ( WarehouseName = 'Lager Berlin'
        CompanyCode   = lv_company1 )

      ( WarehouseName = 'Retourlager Frankfurt'
        CompanyCode   = lv_company1 )

      ( WarehouseName = 'Altlager Frankfurt'
        CompanyCode   = lv_company1
        IsBlocked     = abap_true )

      ( WarehouseName = 'Hauptlager Hamburg'
        CompanyCode   = lv_company2 )

      ( WarehouseName = 'Lager München'
        CompanyCode   = lv_company2 )

      ( WarehouseName = 'Transitlager Hamburg'
        CompanyCode   = lv_company2 )

      ( WarehouseName = 'Hauptlager Kusel'
        CompanyCode   = lv_company3 )

      ( WarehouseName = 'Lager Kaiserslautern'
        CompanyCode   = lv_company3 )
    ).

    LOOP AT lt_create ASSIGNING FIELD-SYMBOL(<ls_create>).
      <ls_create>-%cid = |WAREHOUSE_{ sy-tabix }|.
    ENDLOOP.

    MODIFY ENTITIES OF zmerp_r_warehouse
      ENTITY Warehouse
      CREATE FIELDS ( WarehouseName CompanyCode IsBlocked )
      WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zmerp_r_warehouse
        FAILED DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
    ENDIF.

    IF ls_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
      write_failure(
        iv_text     = '[Warehouse]: Creation failed:'
        it_messages = VALUE #( BASE VALUE #( FOR rep IN ls_reported-warehouse ( rep-%msg ) )
                               FOR com IN ls_commit_reported-warehouse ( com-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    rt_codes = VALUE #( FOR row IN lt_create ( CONV #( ls_mapped-warehouse[ %cid = row-%cid ]-WarehouseCode ) ) ).
    write_log( iv_text = |[Warehouse]: { lines( rt_codes ) } records created.| out = out ).
  ENDMETHOD.

  METHOD create_items.
    TYPES tt_create TYPE TABLE FOR CREATE zmerp_r_item.

    DATA(lv_grp1) = get_code( it_codes = is_codes-item_groups iv_no = 1 ).
    DATA(lv_grp2) = get_code( it_codes = is_codes-item_groups iv_no = 2 ).
    DATA(lv_grp3) = get_code( it_codes = is_codes-item_groups iv_no = 3 ).
    DATA(lv_grp4) = get_code( it_codes = is_codes-item_groups iv_no = 4 ).
    DATA(lv_grp5) = get_code( it_codes = is_codes-item_groups iv_no = 5 ).
    DATA(lv_grp6) = get_code( it_codes = is_codes-item_groups iv_no = 6 ).

    " Default VAT code = the default of the item group (setDefaultVatCode sets the same value)
    DATA(lv_vat7)  = get_code( it_codes = is_codes-vat_rates iv_no = 2 ).
    DATA(lv_vat19) = get_code( it_codes = is_codes-vat_rates iv_no = 3 ).

    DATA(lv_product) = zif_merp_constants=>c_item_type-product.
    DATA(lv_service) = zif_merp_constants=>c_item_type-service.

    DATA(lt_create) = VALUE tt_create(
      " Group 1: Major Home Appliances
      ( Description       = 'Washing Machine Bosch Series 6'
        Article           = 'BSH-WM-600'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp1
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Refrigerator Siemens iQ500'
        Article           = 'SIE-RF-500'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp1
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Dishwasher Miele G7000'
        Article           = 'MIE-DW-700'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp1
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )

      " Group 2: Small Kitchen Appliances
      ( Description       = 'Espresso Machine DeLonghi Magnifica'
        Article           = 'DLG-EM-100'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp2
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Electric Kettle Philips Daily Collection'
        Article           = 'PHL-EK-200'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp2
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Toaster Tefal Express 2-Slot'
        Article           = 'TEF-TS-300'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp2
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )

      " Group 3: Consumer Electronics
      ( Description       = 'Smart TV Samsung 55 Inch OLED'
        Article           = 'SAM-TV-55O'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp3
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Soundbar Sony HT-S400 2.1ch'
        Article           = 'SNE-SB-400'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp3
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Wireless Headphones Bose QuietComfort 45'
        Article           = 'BOS-HP-QC45'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp3
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )

      " Group 4: Accessories & Supplies
      ( Description       = 'HDMI Cable 2.0 High Speed (2m)'
        Article           = 'ACC-HDMI-02'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp4
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Washing Machine Water Inlet Hose (1.5m)'
        Article           = 'ACC-HOSE-15'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp4
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )
      ( Description       = 'Descaling Solution for Coffee Machines 500ml'
        Article           = 'ACC-DESC-50'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp4
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA' )

      " Group 5: Installation & Support Services
      ( Description       = 'Home Appliance Installation Service'
        Article           = 'SRV-INST-01'
        ItemTypeCode      = lv_service
        ItemGroupCode     = lv_grp5
        DefaultVatCode    = lv_vat7
        BaseUnitOfMeasure = 'H' )
      ( Description       = 'Extended Warranty & On-site Repair Service'
        Article           = 'SRV-REPR-02'
        ItemTypeCode      = lv_service
        ItemGroupCode     = lv_grp5
        DefaultVatCode    = lv_vat7
        BaseUnitOfMeasure = 'H' )

      " Group 6: Legacy Office Equipment (blocked)
      ( Description       = 'Siemens Optipoint 500 Entry'
        Article           = 'SIE-TEL-500'
        ItemTypeCode      = lv_product
        ItemGroupCode     = lv_grp6
        DefaultVatCode    = lv_vat19
        BaseUnitOfMeasure = 'EA'
        IsBlocked         = abap_true )

      ( Description       = 'Express Delivery and Connection Service'
        Article           = 'SRV-DELIV-03'
        ItemTypeCode      = lv_service
        ItemGroupCode     = lv_grp5
        DefaultVatCode    = lv_vat7
        BaseUnitOfMeasure = 'EA' )
    ).

    LOOP AT lt_create ASSIGNING FIELD-SYMBOL(<ls_create>).
      <ls_create>-%cid = |ITEM_{ sy-tabix }|.
    ENDLOOP.

    MODIFY ENTITIES OF zmerp_r_item
      ENTITY Item
      CREATE FIELDS ( Description Article ItemTypeCode ItemGroupCode DefaultVatCode BaseUnitOfMeasure IsBlocked )
      WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zmerp_r_item
        FAILED DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
    ENDIF.

    IF ls_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
      write_failure(
        iv_text     = '[Item]: Creation failed:'
        it_messages = VALUE #( BASE VALUE #( FOR rep IN ls_reported-item ( rep-%msg ) )
                               FOR com IN ls_commit_reported-item ( com-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    rt_codes = VALUE #( FOR row IN lt_create ( CONV #( ls_mapped-item[ %cid = row-%cid ]-ItemCode ) ) ).
    write_log( iv_text = |[Item]: { lines( rt_codes ) } records created.| out = out ).
  ENDMETHOD.

  METHOD create_business_partners.
    TYPES tt_create TYPE TABLE FOR CREATE zmerp_r_bus_partner.

    DATA(lt_create) = VALUE tt_create(
      " --- Suppliers ---
      ( PartnerName = 'Bosch-Siemens Hausgeräte GmbH'
        IsSupplier  = abap_true
        TaxNumber   = 'DE129323400'
        Address     = 'Carl-Wery-Straße 34'
        City        = 'München'
        Country     = 'DE'
        Phone       = '+49 89 459001'
        Email       = 'contact@bshg.com' )

      ( PartnerName = 'Miele & Cie. KG'
        IsSupplier  = abap_true
        TaxNumber   = 'DE126788901'
        Address     = 'Carl-Miele-Straße 29'
        City        = 'Gütersloh'
        Country     = 'DE'
        Phone       = '+49 5241 890'
        Email       = 'info@miele.de' )

      ( PartnerName = 'DeLonghi Deutschland GmbH'
        IsSupplier  = abap_true
        TaxNumber   = 'DE811234567'
        Address     = 'Carl-Ulrich-Straße 4'
        City        = 'Neu-Isenburg'
        Country     = 'DE'
        Phone       = '+49 6102 5990'
        Email       = 'service@delonghi.de' )

      ( PartnerName = 'Samsung Electronics GmbH'
        IsSupplier  = abap_true
        TaxNumber   = 'DE113546789'
        Address     = 'Am Kronberger Hang 6'
        City        = 'Schwalbach am Taunus'
        Country     = 'DE'
        Phone       = '+49 6196 660'
        Email       = 'info@samsung.de' )

      ( PartnerName = 'Sony Europe B.V. Zweigniederlassung Deutschland'
        IsSupplier  = abap_true
        TaxNumber   = 'DE815678910'
        Address     = 'Kemperplatz 1'
        City        = 'Berlin'
        Country     = 'DE'
        Phone       = '+49 30 585800'
        Email       = 'info@sony.de' )

      " --- Customers ---
      ( PartnerName = 'Media-Saturn Retail Group GmbH'
        IsCustomer  = abap_true
        TaxNumber   = 'DE130123456'
        Address     = 'Media-Saturn-Str. 1'
        City        = 'Ingolstadt'
        Country     = 'DE'
        Phone       = '+49 841 6340'
        Email       = 'einkauf@mediamarkt.de' )

      ( PartnerName = 'Expert SE'
        IsCustomer  = abap_true
        TaxNumber   = 'DE115678123'
        Address     = 'Bayernstraße 4'
        City        = 'Langenhagen'
        Country     = 'DE'
        Phone       = '+49 511 78080'
        Email       = 'zentrale@expert.de' )

      ( PartnerName = 'Euronics Deutschland eG'
        IsCustomer  = abap_true
        TaxNumber   = 'DE147890123'
        Address     = 'Berliner Straße 11'
        City        = 'Ditzingen'
        Country     = 'DE'
        Phone       = '+49 7156 9280'
        Email       = 'info@euronics.de' )

      ( PartnerName = 'Elektro-Service Müller GmbH'
        IsCustomer  = abap_true
        TaxNumber   = 'DE289012345'
        Address     = 'Trierer Straße 12'
        City        = 'Kusel'
        Country     = 'DE'
        Phone       = '+49 6381 1234'
        Email       = 'service@elektro-mueller.de' )

      ( PartnerName = 'Küchenstudio Schmidt GmbH'
        IsCustomer  = abap_true
        TaxNumber   = 'DE301234567'
        Address     = 'Zeil 45'
        City        = 'Frankfurt am Main'
        Country     = 'DE'
        Phone       = '+49 69 987654'
        Email       = 'vertrieb@kuechen-schmidt.de' )

      " --- Both ---
      ( PartnerName = 'ElectronicPartner GmbH & Co. KG'
        IsCustomer  = abap_true
        IsSupplier  = abap_true
        TaxNumber   = 'DE119345678'
        Address     = 'Mündelheimer Weg 40'
        City        = 'Düsseldorf'
        Country     = 'DE'
        Phone       = '+49 211 41560'
        Email       = 'partner@electronicpartner.de' )

      ( PartnerName = 'Conrad Electronic SE'
        IsCustomer  = abap_true
        IsSupplier  = abap_true
        TaxNumber   = 'DE133123789'
        Address     = 'Klaus-Conrad-Straße 1'
        City        = 'Hirschau'
        Country     = 'DE'
        Phone       = '+49 9622 300'
        Email       = 'b2b@conrad.de' )

      ( PartnerName = 'Radio Shack GmbH'
        IsCustomer  = abap_true
        IsSupplier  = abap_true
        TaxNumber   = 'DE149990123'
        Address     = 'Hanauer Landstraße 150'
        City        = 'Frankfurt am Main'
        Country     = 'DE'
        Phone       = '+49 69 450012'
        Email       = 'info@radioshack.de'
        IsBlocked   = abap_true )
    ).

    LOOP AT lt_create ASSIGNING FIELD-SYMBOL(<ls_create>).
      <ls_create>-%cid = |PARTNER_{ sy-tabix }|.
    ENDLOOP.

    MODIFY ENTITIES OF zmerp_r_bus_partner
      ENTITY BusinessPartner
      CREATE FIELDS ( PartnerName IsCustomer IsSupplier TaxNumber Address City Country Phone Email IsBlocked )
      WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zmerp_r_bus_partner
        FAILED DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
    ENDIF.

    IF ls_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
      write_failure(
        iv_text     = '[Business Partner]: Creation failed:'
        it_messages = VALUE #( BASE VALUE #( FOR rep IN ls_reported-businesspartner ( rep-%msg ) )
                               FOR com IN ls_commit_reported-businesspartner ( com-%msg ) )
        out         = out ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    rt_codes = VALUE #( FOR row IN lt_create ( CONV #( ls_mapped-businesspartner[ %cid = row-%cid ]-PartnerCode ) ) ).
    write_log( iv_text = |[Business Partner]: { lines( rt_codes ) } records created.| out = out ).
  ENDMETHOD.

  METHOD setup_master_data.
    " One commit per level: the validations of a level read the master data
    " of the previous levels from the database. A failed level stops the setup.
    rs_codes-companies = create_company_codes( out ).
    IF rs_codes-companies IS INITIAL.
      CLEAR rs_codes.
      RETURN.
    ENDIF.

    rs_codes-vat_rates = create_vat_rates( out ).
    IF rs_codes-vat_rates IS INITIAL.
      CLEAR rs_codes.
      RETURN.
    ENDIF.

    rs_codes-item_groups = create_item_groups( is_codes = rs_codes out = out ).
    IF rs_codes-item_groups IS INITIAL.
      CLEAR rs_codes.
      RETURN.
    ENDIF.

    rs_codes-warehouses = create_warehouses( is_codes = rs_codes out = out ).
    IF rs_codes-warehouses IS INITIAL.
      CLEAR rs_codes.
      RETURN.
    ENDIF.

    rs_codes-items = create_items( is_codes = rs_codes out = out ).
    IF rs_codes-items IS INITIAL.
      CLEAR rs_codes.
      RETURN.
    ENDIF.

    rs_codes-partners = create_business_partners( out ).
    IF rs_codes-partners IS INITIAL.
      CLEAR rs_codes.
      RETURN.
    ENDIF.

    " Number range levels follow the created master data; committed before the documents:
    " number assignment (number_get) must not wait for our own uncommitted interval changes
    zcl_merp_num_range_util=>sync_master_intervals_from_db( ).
    COMMIT WORK.
  ENDMETHOD.

  METHOD setup_documents.
    " Readable amounts: every line (also of a partial receipt) has a net amount that is a multiple of 100,
    " so VAT (19% / 7%) and gross amounts have no cents. Two exceptions show how the last receipt closes
    " the rounding cents of a purchase order item:
    "   PO 1: TV 3 x 1199.99 at 19% VAT = 3599.97 net, VAT 683.9943 -> 683.99
    "     GR 1:  2 TVs = 2399.98 net, VAT 455.9962 -> 456.00
    "     GR 2:  last TV = 1199.99 net, VAT 227.9981 -> 228.00 by calculation,
    "            but takes the open VAT 683.99 - 456.00 = 227.99 -> PO item closed to 0.00
    "   PO 7: TV 4 x 599.99 at 19% VAT = 2399.96 net, VAT 455.9924 -> 455.99
    "     GR 1:  2 TVs = 1199.98 net, VAT 228.00;  GR 2: 1 TV = 599.99 net, VAT 114.00
    "     The last TV stays open for a live demo: 114.00 by calculation, takes 455.99 - 342.00 = 113.99
    " Units: EA for goods, H for services charged by the hour (units of the SAP standard).

    " PO 1 (1000, Samsung): received completely by two goods receipts -> 'Completed'
    DATA(lv_po1) = create_purchase_order(
      is_po = VALUE #( company_no   = 1      warehouse_no = 1 partner_no = 4
                       days_ago     = 3      delivery_in  = 2
                       responsible  = 'SCHMIDT_A'
                       remarks      = 'TV season stock'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 7  quantity = 3  price = '1199.99' )
                                               ( item_no = 10 quantity = 10 price = '10.00' )
                                               ( item_no = 14 quantity = 3  price = '100.00' ) ) )
      is_codes = is_codes
      out      = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po1
                       days_ago    = 1
                       responsible = 'SCHMIDT_A'
                       remarks     = 'Delivery 1 of 2: 1 TV with warranty follows'
                       post        = abap_true
                       lines       = VALUE #( ( item_no = 7  quantity = 2 )
                                              ( item_no = 14 quantity = 2 ) ) )
      is_codes = is_codes
      out      = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po1
                       days_ago    = 0
                       responsible = 'SCHMIDT_A'
                       remarks     = 'Delivery 2 of 2: last TV with warranty closes the cents'
                       post        = abap_true )
      is_codes = is_codes
      out      = out ).

    " PO 2 (1000, Bosch): partially received -> 'In Delivery' (2 washing machines and 2 h installation open)
    DATA(lv_po2) = create_purchase_order(
      is_po = VALUE #( company_no   = 1      warehouse_no = 2 partner_no = 1
                       days_ago     = 2      delivery_in  = 5
                       responsible  = 'MUELLER_M'
                       remarks      = 'Large appliances with installation'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 1  quantity = 5  price = '500.00' )
                                               ( item_no = 2  quantity = 2  price = '800.00' )
                                               ( item_no = 11 quantity = 10 price = '10.00' )
                                               ( item_no = 13 quantity = 4  price = '50.00' ) ) )
      is_codes = is_codes
      out      = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po2
                       days_ago    = 0
                       responsible = 'MUELLER_M'
                       remarks     = 'Partial delivery: 2 washing machines and 2 h installation open'
                       post        = abap_true
                       lines       = VALUE #( ( item_no = 1  quantity = 3 )
                                              ( item_no = 13 quantity = 2 ) ) )
      is_codes = is_codes
      out      = out ).

    " PO 3 (1000, DeLonghi): released; the goods receipt is prepared but not posted yet
    "   -> purchase order 'Approved', goods receipt 'New'
    DATA(lv_po3) = create_purchase_order(
      is_po = VALUE #( company_no   = 1      warehouse_no = 1 partner_no = 3
                       days_ago     = 1      delivery_in  = 4
                       responsible  = 'MUELLER_M'
                       remarks      = 'Coffee machines and supplies'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 4  quantity = 4  price = '400.00' )
                                               ( item_no = 12 quantity = 10 price = '10.00' )
                                               ( item_no = 5  quantity = 10 price = '30.00' )
                                               ( item_no = 16 quantity = 1  price = '100.00' ) ) )
      is_codes = is_codes
      out      = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po3
                       days_ago    = 0
                       responsible = 'MUELLER_M'
                       remarks     = 'Goods arrived, receipt to be checked and posted'
                       post        = abap_false )
      is_codes = is_codes
      out      = out ).

    " PO 4 (2000, Conrad): released, nothing received -> 'Approved'
    create_purchase_order(
      is_po = VALUE #( company_no   = 2      warehouse_no = 6 partner_no = 12
                       days_ago     = 2      delivery_in  = 6
                       responsible  = 'FISCHER_K'
                       remarks      = 'Audio assortment for Hamburg'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 9  quantity = 10 price = '300.00' )
                                               ( item_no = 8  quantity = 4  price = '250.00' )
                                               ( item_no = 10 quantity = 20 price = '10.00' )
                                               ( item_no = 16 quantity = 1  price = '100.00' ) ) )
      is_codes = is_codes
      out      = out ).

    " PO 5 (2000, Sony): received completely by one goods receipt -> 'Completed' (stock in Munich)
    DATA(lv_po5) = create_purchase_order(
      is_po = VALUE #( company_no   = 2      warehouse_no = 7 partner_no = 5
                       days_ago     = 4      delivery_in  = 1
                       responsible  = 'FISCHER_K'
                       remarks      = 'Audio stock for Munich'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 8 quantity = 6 price = '250.00' )
                                               ( item_no = 9 quantity = 5 price = '300.00' ) ) )
      is_codes = is_codes
      out      = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po5
                       days_ago    = 1
                       responsible = 'FISCHER_K'
                       remarks     = 'Complete delivery'
                       post        = abap_true )
      is_codes = is_codes
      out      = out ).

    " PO 6 (3000, ElectronicPartner): not released -> 'New'
    create_purchase_order(
      is_po = VALUE #( company_no   = 3      warehouse_no = 9 partner_no = 11
                       days_ago     = 1      delivery_in  = 7
                       responsible  = 'WEBER_J'
                       remarks      = 'Modevi starter set, waiting for approval'
                       release      = abap_false
                       lines        = VALUE #( ( item_no = 6 quantity = 10 price = '40.00' )
                                               ( item_no = 5 quantity = 10 price = '30.00' ) ) )
      is_codes = is_codes
      out      = out ).

    " PO 7 (3000, Samsung): two partial receipts -> 'In Delivery'
    "   (1 TV, 1 cable and 1 h warranty stay open for a live demo of the cents case, see above)
    DATA(lv_po7) = create_purchase_order(
      is_po = VALUE #( company_no   = 3      warehouse_no = 9 partner_no = 4
                       days_ago     = 1      delivery_in  = 7
                       responsible  = 'WEBER_J'
                       remarks      = 'TV season stock'
                       release      = abap_true
                       lines        = VALUE #( ( item_no = 7  quantity = 4  price = '599.99' )
                                               ( item_no = 10 quantity = 4  price = '10.00' )
                                               ( item_no = 14 quantity = 4  price = '100.00' ) ) )
      is_codes = is_codes
      out      = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po7
                       days_ago    = 1
                       responsible = 'WEBER_J'
                       remarks     = 'Delivery 1: 2 TVs, 2 cables and 2 h warranty'
                       post        = abap_true
                       lines       = VALUE #( ( item_no = 7  quantity = 2 )
                                              ( item_no = 10 quantity = 2 )
                                              ( item_no = 14 quantity = 2 ) ) )
      is_codes = is_codes
      out      = out ).

    create_goods_receipt(
      is_gr = VALUE #( po_uuid     = lv_po7
                       days_ago    = 0
                       responsible = 'WEBER_J'
                       remarks     = 'Delivery 2: 1 TV, 1 cable and 1 h warranty; the rest follows'
                       post        = abap_true
                       lines       = VALUE #( ( item_no = 7  quantity = 1 )
                                              ( item_no = 10 quantity = 1 )
                                              ( item_no = 14 quantity = 1 ) ) )
      is_codes = is_codes
      out      = out ).

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
    DATA(lv_today)        = cl_abap_context_info=>get_system_date( ).
    DATA(lv_company_code) = get_code( it_codes = is_codes-companies iv_no = is_po-company_no ).

    " 1. Header and items: currency, item defaults and amounts are derived by the purchase order logic
    MODIFY ENTITIES OF zmerp_r_purchaseorder
      ENTITY PurchaseOrder
        CREATE FIELDS ( CompanyCode WarehouseCode BusinessPartnerCode DocumentDate DeliveryDate
                        ResponsiblePerson Remarks )
        WITH VALUE #( ( %cid                = 'PO'
                        CompanyCode         = lv_company_code
                        WarehouseCode       = get_code( it_codes = is_codes-warehouses iv_no = is_po-warehouse_no )
                        BusinessPartnerCode = get_code( it_codes = is_codes-partners iv_no = is_po-partner_no )
                        DocumentDate        = CONV d( lv_today - is_po-days_ago )
                        DeliveryDate        = CONV d( lv_today + is_po-delivery_in )
                        ResponsiblePerson   = is_po-responsible
                        Remarks             = is_po-remarks ) )
        CREATE BY \_Items
        FIELDS ( ItemCode Quantity Price )
        WITH VALUE #( ( %cid_ref = 'PO'
                        %target  = VALUE #( FOR po_line IN is_po-lines INDEX INTO lv_index
                                            ( %cid     = |PO_ITEM_{ lv_index }|
                                              ItemCode = get_code( it_codes = is_codes-items iv_no = po_line-item_no )
                                              Quantity = po_line-quantity
                                              Price    = po_line-price ) ) ) )
      MAPPED DATA(ls_mapped).

    rv_po_uuid = VALUE #( ls_mapped-purchaseorder[ 1 ]-DocumentUUID OPTIONAL ).

    COMMIT ENTITIES RESPONSE OF zmerp_r_purchaseorder
      FAILED DATA(ls_save_failed)
      REPORTED DATA(ls_save_reported).

    IF ls_save_failed IS NOT INITIAL OR rv_po_uuid IS INITIAL.
      write_failure(
        iv_text     = |[Purchase Order]: Creation for company { lv_company_code } failed:|
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
          iv_text     = |[Purchase Order]: Release for company { lv_company_code } failed:|
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
        FOR gr_line IN is_gr-lines ( item_code = get_code( it_codes = is_codes-items iv_no = gr_line-item_no )
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

