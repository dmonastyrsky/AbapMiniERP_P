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

    "! Tests validation returning missing company keys
    METHODS test_validate_mix          FOR TESTING RAISING cx_static_check.

    "! Tests validation when all provided keys are valid
    METHODS test_validate_all_valid    FOR TESTING RAISING cx_static_check.

    "! Tests validation with empty input table
    METHODS test_validate_empty        FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_md_comp_code_sel IMPLEMENTATION.

  METHOD class_setup.
    " Initialize SQL double framework for CDS view zmerp_r_company_code
    mo_sql_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZMERP_R_COMPANY_CODE' ) )
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

  METHOD test_validate_mix.
    " Prepare mock data
    DATA lt_mock TYPE STANDARD TABLE OF zmerp_r_company_code WITH EMPTY KEY.
    lt_mock = VALUE #( ( companycode = '1000' ) ( companycode = '2000' ) ).
    mo_sql_env->insert_test_data( lt_mock ).

    " Input with 1 existing, 1 missing, 1 duplicate missing
    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.
    lt_keys = VALUE #(
      ( CompanyCode = '1000' )
      ( CompanyCode = '9999' )
      ( CompanyCode = '9999' )
    ).

    " Execute
    DATA(lt_invalid) = mo_cut->validate_companies( lt_keys ).

    " Assert
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_invalid )
      exp = 1
      msg = 'Exactly one unique company code should be flagged as invalid.'
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_invalid[ 1 ]-CompanyCode
      exp = '9999'
      msg = 'Key 9999 should be identified as invalid.'
    ).
  ENDMETHOD.

  METHOD test_validate_all_valid.
    DATA lt_mock TYPE STANDARD TABLE OF zmerp_r_company_code WITH EMPTY KEY.
    lt_mock = VALUE #( ( companycode = '1000' ) ).
    mo_sql_env->insert_test_data( lt_mock ).

    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.
    lt_keys = VALUE #( ( CompanyCode = '1000' ) ).

    DATA(lt_invalid) = mo_cut->validate_companies( lt_keys ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_invalid
      msg = 'All keys exist, so invalid result table must be empty.'
    ).
  ENDMETHOD.

  METHOD test_validate_empty.
    DATA lt_keys TYPE zif_merp_md_comp_code_sel=>tt_company_keys.

    DATA(lt_invalid) = mo_cut->validate_companies( lt_keys ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_invalid
      msg = 'Empty input should return empty invalid table.'
    ).
  ENDMETHOD.

ENDCLASS.
