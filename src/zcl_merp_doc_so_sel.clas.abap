CLASS zcl_merp_doc_so_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_merp_doc_so_sel.

  PRIVATE SECTION.
    "! Cleanses, sorts and removes duplicates from input document keys
    "! @parameter it_keys | Raw table of technical keys
    "! @parameter rt_keys | Processed clean table of technical keys
    METHODS prepare_keys
      IMPORTING it_keys        TYPE zif_merp_doc_so_sel=>tt_document_keys
      RETURNING VALUE(rt_keys) TYPE zif_merp_doc_so_sel=>tt_document_keys.
ENDCLASS.


CLASS zcl_merp_doc_so_sel IMPLEMENTATION.

  METHOD zif_merp_doc_so_sel~read_headers.
    DATA(lt_clean_keys) = prepare_keys( it_document_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " ty_header is derived from the same view, so INTO TABLE (without CORRESPONDING)
    " makes any structure mismatch visible at compile time instead of silently skipping fields
    SELECT so~*
      FROM zmerp_r_salesorder AS so
      INNER JOIN @lt_clean_keys AS keys ON so~DocumentUUID = keys~DocumentUUID
      INTO TABLE @rt_headers.
  ENDMETHOD.


  METHOD zif_merp_doc_so_sel~read_progress.
    DATA(lt_clean_keys) = prepare_keys( it_document_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " ty_progress is derived from the same view, see the comment in read_headers
    SELECT prg~*
      FROM zmerp_i_so_progress AS prg
      INNER JOIN @lt_clean_keys AS keys ON prg~SoHeaderUUID = keys~DocumentUUID
      INTO TABLE @rt_progress.
  ENDMETHOD.


  METHOD zif_merp_doc_so_sel~read_usages.
    DATA(lt_clean_keys) = prepare_keys( it_document_keys ).
    IF lt_clean_keys IS INITIAL.
      RETURN.
    ENDIF.

    " DISTINCT: one row per document and using entity, however many documents reference it
    SELECT DISTINCT usage~DocumentUUID, usage~UsedInEntity
      FROM zmerp_i_so_usage AS usage
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
