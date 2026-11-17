CLASS zcl_merp_doc_st_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_doc_st_sel.

  PRIVATE SECTION.
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_doc_st_sel=>tt_document_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_doc_st_sel=>tt_document_keys.
ENDCLASS.



CLASS zcl_merp_doc_st_sel IMPLEMENTATION.

  METHOD zif_merp_doc_st_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_document_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT DISTINCT usage~DocumentUUID, usage~UsedInEntity
      FROM zmerp_i_stocktransfer_usage AS usage
      INNER JOIN @lt_clean_keys AS keys ON usage~DocumentUUID = keys~DocumentUUID
      INTO CORRESPONDING FIELDS OF TABLE @rt_usages.
  ENDMETHOD.


  METHOD prepare_keys.
    rt_keys = it_keys.
    DELETE rt_keys WHERE DocumentUUID IS INITIAL.
    SORT rt_keys BY DocumentUUID.
    DELETE ADJACENT DUPLICATES FROM rt_keys COMPARING DocumentUUID.
  ENDMETHOD.
ENDCLASS.
