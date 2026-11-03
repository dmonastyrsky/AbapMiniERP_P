CLASS ltcl_md_comp_code_sel DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA mo_sql_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_merp_md_comp_code_sel.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.

    "! Tests reading a single company code when a valid key is provided
    METHODS test_read_single_success   FOR TESTING RAISING cx_static_check.

    "! Tests single company retrieval with initial key (expects exception)
    METHODS test_read_single_initial   FOR TESTING RAISING cx_static_check.

    "! Tests single company retrieval when company does not exist (expects exception)
    METHODS test_read_single_not_found FOR TESTING RAISING cx_static_check.

    "! Tests bulk reading with valid keys
    METHODS test_read_bulk_success     FOR TESTING RAISING cx_static_check.

    "! Tests bulk reading with duplicate and initial keys in input
    METHODS test_read_bulk_dedup       FOR TESTING RAISING cx_static_check.

    "! Tests bulk reading with empty input table
    METHODS test_read_bulk_empty       FOR TESTING RAISING cx_static_check.

    "! Tests reading usages: one row per code and using entity, unused codes are not returned
    METHODS test_read_usages           FOR TESTING RAISING cx_static_check.

    "! Tests reading usages with empty input table
    METHODS test_read_usages_empty     FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_md_comp_code_sel IMPLEMENTATION.

  METHOD class_setup.
    " Initialize SQL double framework for the company code view and its usage view
    mo_sql_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZMERP_R_COMPANY_CODE' )
                                   ( 'ZMERP_I_COMPANY_CODE_USAGE' ) )
    ).
  ENDMETHOD.

  METHOD class_teardown.
    mo_sql_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    mo_sql_env->clear_doubles( ).
    mo_cut = NEW zcl_merp_md_comp_code_sel( ).
  ENDMETHOD.

  METHOD test_read_single_success.
    " Prepare mock data
    DATA lt_mock TYPE STANDARD TABLE OF zmerp_r_company_code WITH EMPTY KEY.
    lt_mock = VALUE #(
      ( companycode = '1000' companyname = 'Company 1000' currencycode = 'EUR' )
      ( companycode = '2000' companyname = 'Company 2000' currencycode = 'USD' )
    ).
    mo_sql_env->insert_test_data( lt_mock ).

    " Execute method
    DATA(ls_act) = mo_cut->read_company( '1000' ).

    " Assert
    cl_abap_unit_assert=>assert_equals(
      act = ls_act-CompanyCode
      exp = '1000'
      msg = 'Company code should match requested key.'
    ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_act-CompanyName
      exp = 'Company 1000'
      msg = 'Company name should match test double data.'
    ).
  ENDMETHOD.

  METHOD test_read_single_initial.
    TRY.
        mo_cut->read_company( '' ).
        cl_abap_unit_assert=>fail( msg = 'Exception zcx_merp_master_data expected for initial key.' ).
      CATCH zcx_merp_md.
        " Exception successfully caught
    ENDTRY.
  ENDMETHOD.

  METHOD test_read_single_not_found.
    TRY.
        mo_cut->read_company( '9999' ).
        cl_abap_unit_assert=>fail( msg = 'Exception zcx_merp_master_data expected when key is not found.' ).
      CATCH zcx_merp_md.
        " Exception successfully caught
    ENDTRY.
  ENDMETHOD.

  METHOD test_read_bulk_success.
    " Prepare mock data
    DATA lt_mock TYPE STANDARD TABLE OF zmerp_r_company_code WITH EMPTY KEY.
    lt_mock = VALUE #(
      ( companycode = '1000' companyname = 'Company 1000' )
      ( companycode = '2000' companyname = 'Company 2000' )
    ).
    mo_sql_env->insert_test_data( lt_mock ).

    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.
    lt_keys = VALUE #( ( CompanyCode = '1000' ) ( CompanyCode = '2000' ) ).

    " Execute
    DATA(lt_act) = mo_cut->read_companies( lt_keys ).

    " Assert
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_act )
      exp = 2
      msg = 'Should return exactly 2 company records.'
    ).
  ENDMETHOD.

  METHOD test_read_bulk_dedup.
    " Prepare mock data
    DATA lt_mock TYPE STANDARD TABLE OF zmerp_r_company_code WITH EMPTY KEY.
    lt_mock = VALUE #(
      ( companycode = '1000' companyname = 'Company 1000' )
      ( companycode = '2000' companyname = 'Company 2000' )
    ).
    mo_sql_env->insert_test_data( lt_mock ).

    " Input contains duplicates and an initial/empty key
    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.
    lt_keys = VALUE #(
      ( CompanyCode = '1000' )
      ( CompanyCode = '1000' )
      ( CompanyCode = '' )
      ( CompanyCode = '2000' )
    ).

    " Execute
    DATA(lt_act) = mo_cut->read_companies( lt_keys ).

    " Assert deduplication and empty line removal in prepare_keys
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_act )
      exp = 2
      msg = 'Duplicates and empty keys should be filtered out resulting in 2 records.'
    ).
  ENDMETHOD.

  METHOD test_read_bulk_empty.
    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.

    DATA(lt_act) = mo_cut->read_companies( lt_keys ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_act
      msg = 'Empty input keys should return empty result table.'
    ).
  ENDMETHOD.

  METHOD test_read_usages.
    " Company 1000 is used by two warehouses and one purchase order, company 2000 is not used
    DATA lt_mock TYPE STANDARD TABLE OF zmerp_i_company_code_usage WITH EMPTY KEY.
    lt_mock = VALUE #(
      ( CompanyCode = '1000' RefEntityKey = 'WH001' UsedInEntity = 'Warehouse' )
      ( CompanyCode = '1000' RefEntityKey = 'WH002' UsedInEntity = 'Warehouse' )
      ( CompanyCode = '1000' RefEntityKey = 'PO0001' UsedInEntity = 'Purchase Order' IsDocument = abap_true )
    ).
    mo_sql_env->insert_test_data( lt_mock ).

    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.
    lt_keys = VALUE #( ( CompanyCode = '1000' ) ( CompanyCode = '2000' ) ).

    " Execute
    DATA(lt_act) = mo_cut->read_usages( lt_keys ).

    " Assert: one row per using entity, unused company not returned
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_act )
      exp = 2
      msg = 'Company 1000 should be returned once per using entity (Warehouse, Purchase Order).'
    ).

    cl_abap_unit_assert=>assert_false(
      act = xsdbool( line_exists( lt_act[ CompanyCode = '2000' ] ) )
      msg = 'Unused company 2000 must not be returned.'
    ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( lt_act[ CompanyCode = '1000' UsedInEntity = 'Purchase Order' IsDocument = abap_true ] ) )
      msg = 'Usage in a document must be marked IsDocument.'
    ).
  ENDMETHOD.

  METHOD test_read_usages_empty.
    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.

    DATA(lt_act) = mo_cut->read_usages( lt_keys ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_act
      msg = 'Empty input should return empty usage table.'
    ).
  ENDMETHOD.

ENDCLASS.

