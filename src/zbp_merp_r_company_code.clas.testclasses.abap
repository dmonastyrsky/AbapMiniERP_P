*"! @testing BDEF:ZMERP_R_COMPANY_CODE
CLASS ltc_zmerp_r_company_code DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA:
      cds_test_env       TYPE REF TO if_cds_test_environment,
      usage_cds_test_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS:
      class_setup,
      class_teardown.

    METHODS:
      setup,
      teardown,

      "! Tests validation failure when mandatory fields are missing
      validate_mandatory_missing FOR TESTING RAISING cx_static_check,

      "! Tests successful creation with all mandatory fields
      validate_mandatory_success FOR TESTING RAISING cx_static_check,

      "! Tests lowercase prefix is formatted to uppercase
      format_prefix FOR TESTING RAISING cx_static_check,

      "! Tests deletion precheck dependency blockage
      precheck_delete_blocked FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_zmerp_r_company_code IMPLEMENTATION.

  METHOD class_setup.
    cds_test_env       = cl_cds_test_environment=>create( i_for_entity = 'ZMERP_R_COMPANY_CODE' ).
    usage_cds_test_env = cl_cds_test_environment=>create( i_for_entity = 'ZMERP_I_COMPANY_CODE_USAGE' ).
  ENDMETHOD.

  METHOD class_teardown.
    cds_test_env->destroy( ).
    usage_cds_test_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    cds_test_env->clear_doubles( ).
    usage_cds_test_env->clear_doubles( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD validate_mandatory_missing.
    MODIFY ENTITIES OF zmerp_r_company_code
      ENTITY CompanyCode
      CREATE FIELDS ( CompanyCode )
      WITH VALUE #( ( %cid = 'CID_1' CompanyCode = '2000' ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSE OF zmerp_r_company_code
      FAILED DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    cl_abap_unit_assert=>assert_not_initial( ls_commit_failed-companycode ).
  ENDMETHOD.

  METHOD validate_mandatory_success.
    MODIFY ENTITIES OF zmerp_r_company_code
      ENTITY CompanyCode
      CREATE FIELDS ( CompanyCode CompanyName CompanyPrefix CurrencyCode Country )
      WITH VALUE #( ( %cid          = 'CID_2'
                      CompanyCode   = '1000'
                      CompanyName   = 'Test Company Ltd'
                      CompanyPrefix = 'TE'
                      CurrencyCode  = 'EUR'
                      Country       = 'DE' ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSE OF zmerp_r_company_code
      FAILED DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    cl_abap_unit_assert=>assert_initial( ls_commit_failed-companycode ).
  ENDMETHOD.

  METHOD format_prefix.
    MODIFY ENTITIES OF zmerp_r_company_code
      ENTITY CompanyCode
      CREATE FIELDS ( CompanyCode CompanyPrefix )
      WITH VALUE #( ( %cid = 'CID_3' CompanyCode = '7000' CompanyPrefix = 'ab' ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    READ ENTITIES OF zmerp_r_company_code
      ENTITY CompanyCode
      FIELDS ( CompanyPrefix )
      WITH VALUE #( ( CompanyCode = '7000' ) )
      RESULT DATA(lt_result).

    cl_abap_unit_assert=>assert_not_initial( lt_result ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_result[ 1 ]-CompanyPrefix
      exp = 'AB' ).
  ENDMETHOD.

  METHOD precheck_delete_blocked.
    DATA lt_usage TYPE TABLE OF zmerp_i_company_code_usage.
    lt_usage = VALUE #( ( companycode = '8100' usedinentity = 'ZMERP_SO_HEADER' ) ).
    usage_cds_test_env->insert_test_data( i_data = lt_usage ).

    MODIFY ENTITIES OF zmerp_r_company_code
      ENTITY CompanyCode
      DELETE FROM VALUE #( ( CompanyCode = '8100' ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_not_initial( ls_failed-companycode ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_failed-companycode[ 1 ]-%fail-cause
      exp = if_abap_behv=>cause-dependency ).
  ENDMETHOD.

ENDCLASS.
