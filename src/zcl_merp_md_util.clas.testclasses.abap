*"* use this source file for your ABAP unit test classes

CLASS ltcl_md_util DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA mo_sql_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.

    "! Tests single VAT retrieval when a valid item group code is provided
    METHODS test_get_single_vat_success FOR TESTING RAISING cx_static_check.

    "! Tests single VAT retrieval with initial/empty input
    METHODS test_get_single_vat_initial FOR TESTING RAISING cx_static_check.

    "! Tests bulk VAT retrieval with duplicate and empty inputs
    METHODS test_get_bulk_vat_success   FOR TESTING RAISING cx_static_check.

    "! Tests bulk VAT retrieval with empty input table
    METHODS test_get_bulk_vat_empty     FOR TESTING RAISING cx_static_check.

    "! Tests company validation returning invalid codes
    METHODS test_validate_comp_mix      FOR TESTING RAISING cx_static_check.

    "! Tests company validation with empty input table
    METHODS test_validate_comp_empty    FOR TESTING RAISING cx_static_check.

    "! Tests check_dependencies with initial parameters
    METHODS test_check_deps_initial     FOR TESTING RAISING cx_static_check.

    "! Tests check_dependencies when dependency usage is found
    METHODS test_check_deps_found       FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_md_util IMPLEMENTATION.

  METHOD class_setup.
    " Initialize SQL double framework for database entities used by the utility class
    mo_sql_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZMERP_ITEM_GROUP' )
        ( 'ZMERP_R_COMPANY_CODE' )
      )
    ).
  ENDMETHOD.

  METHOD class_teardown.
    " Environment cleanup
    mo_sql_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    " Clear mock test data before each test execution
    mo_sql_env->clear_doubles( ).
  ENDMETHOD.

  METHOD test_get_single_vat_success.
    " Prepare mock data
    DATA lt_item_groups TYPE STANDARD TABLE OF zmerp_item_group WITH EMPTY KEY.
    lt_item_groups = VALUE #(
      ( item_group_code = 'GRP_A' default_vat_code = 'VAT_20' )
      ( item_group_code = 'GRP_B' default_vat_code = 'VAT_07' )
    ).
    mo_sql_env->insert_test_data( lt_item_groups ).

    " Execute method
    DATA(lv_act_vat) = zcl_merp_md_util=>get_item_group_default_vat( 'GRP_A' ).

    " Assert
    cl_abap_unit_assert=>assert_equals(
      act = lv_act_vat
      exp = 'VAT_20'
      msg = 'Default VAT code for single group should match mock data.'
    ).
  ENDMETHOD.

  METHOD test_get_single_vat_initial.
    " Execute with initial value
    DATA(lv_act_vat) = zcl_merp_md_util=>get_item_group_default_vat( '' ).

    " Assert
    cl_abap_unit_assert=>assert_initial(
      act = lv_act_vat
      msg = 'Initial input code must return initial VAT code.'
    ).
  ENDMETHOD.

  METHOD test_get_bulk_vat_success.
    " Prepare mock data
    DATA lt_item_groups TYPE STANDARD TABLE OF zmerp_item_group WITH EMPTY KEY.
    lt_item_groups = VALUE #(
      ( item_group_code = 'GRP_1' default_vat_code = 'V1' )
      ( item_group_code = 'GRP_2' default_vat_code = 'V2' )
    ).
    mo_sql_env->insert_test_data( lt_item_groups ).

    " Input table contains duplicates and an empty value to verify filtering logic
    DATA lt_input TYPE zcl_merp_md_util=>tt_item_group_codes.
    lt_input = VALUE #( ( 'GRP_1' ) ( 'GRP_1' ) ( '' ) ( 'GRP_2' ) ).

    " Execute method
    DATA(lt_act_vats) = zcl_merp_md_util=>get_item_groups_default_vat( lt_input ).

    " Assert
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_act_vats )
      exp = 2
      msg = 'Deduplication and empty line removal should result in 2 unique entries.'
    ).

    IF line_exists( lt_act_vats[ item_group_code = 'GRP_1' ] ).
      cl_abap_unit_assert=>assert_equals(
        act = lt_act_vats[ item_group_code = 'GRP_1' ]-default_vat_code
        exp = 'V1'
        msg = 'VAT code for GRP_1 should be V1.'
      ).
    ELSE.
      cl_abap_unit_assert=>fail( msg = 'Expected entry GRP_1 missing in result.' ).
    ENDIF.
  ENDMETHOD.

  METHOD test_get_bulk_vat_empty.
    DATA lt_input TYPE zcl_merp_md_util=>tt_item_group_codes.

    DATA(lt_act_vats) = zcl_merp_md_util=>get_item_groups_default_vat( lt_input ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_act_vats
      msg = 'Empty input table should return empty result table.'
    ).
  ENDMETHOD.

  METHOD test_validate_comp_mix.
    " Prepare mock data for company codes
    DATA lt_companies TYPE STANDARD TABLE OF zmerp_r_company_code WITH EMPTY KEY.
    lt_companies = VALUE #(
      ( companycode = '1000' )
      ( companycode = '2000' )
    ).
    mo_sql_env->insert_test_data( lt_companies ).

    " Input with 1 valid and 1 invalid code
    DATA lt_input TYPE zcl_merp_md_util=>tt_company_codes.
    lt_input = VALUE #( ( '1000' ) ( '9999' ) ).

    " Execute
    DATA(lt_invalid) = zcl_merp_md_util=>validate_companies( lt_input ).

    " Assert
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_invalid )
      exp = 1
      msg = 'Exactly one company code should be flagged as invalid.'
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_invalid[ 1 ]
      exp = '9999'
      msg = 'Code 9999 should be returned in invalid company list.'
    ).
  ENDMETHOD.

  METHOD test_validate_comp_empty.
    DATA lt_input TYPE zcl_merp_md_util=>tt_company_codes.

    DATA(lt_invalid) = zcl_merp_md_util=>validate_companies( lt_input ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_invalid
      msg = 'Empty input should return empty invalid table.'
    ).
  ENDMETHOD.

  METHOD test_check_deps_initial.
    DATA lt_keys TYPE string_table.

    " Execute with initial mandatory fields
    DATA(lt_results) = zcl_merp_md_util=>check_dependencies(
      it_keys           = lt_keys
      iv_usage_cds      = ''
      iv_key_field_name = ''
      is_textid         = VALUE #( )
    ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_results
      msg = 'Initial input parameters should immediately return empty result.'
    ).
  ENDMETHOD.

  METHOD test_check_deps_found.
    " Mock data insertion for company codes entity
    DATA lt_companies TYPE STANDARD TABLE OF zmerp_r_company_code WITH EMPTY KEY.
    lt_companies = VALUE #( ( companycode = 'COMP_BUSY' ) ).
    mo_sql_env->insert_test_data( lt_companies ).

    DATA lt_keys TYPE string_table.
    lt_keys = VALUE #( ( `COMP_BUSY` ) ).

    DATA lv_dummy_textid TYPE scx_t100key.
    lv_dummy_textid-msgid = 'ZMERP_MSG'.
    lv_dummy_textid-msgno = '001'.

    " Test execution using zmerp_r_company_code as a target view
    DATA(lt_results) = zcl_merp_md_util=>check_dependencies(
      it_keys           = lt_keys
      iv_usage_cds      = 'ZMERP_R_COMPANY_CODE'
      iv_key_field_name = 'CompanyCode'
      is_textid         = lv_dummy_textid
    ).

    " Assert dependency detection
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_results )
      exp = 1
      msg = 'One dependency result should be created for matched key.'
    ).

    IF lt_results IS NOT INITIAL.
      cl_abap_unit_assert=>assert_equals(
        act = lt_results[ 1 ]-key_value
        exp = 'COMP_BUSY'
        msg = 'Blocked key value should match the input key.'
      ).
      cl_abap_unit_assert=>assert_bound(
        act = lt_results[ 1 ]-msg
        msg = 'Message reference object should be instantiated.'
      ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
