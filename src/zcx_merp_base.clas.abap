CLASS zcx_merp_base DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.
    INTERFACES if_t100_message.
    INTERFACES if_abap_behv_message.

    DATA mv_attr1 TYPE string.
    DATA mv_attr2 TYPE string.
    DATA mv_attr3 TYPE string.
    DATA mv_attr4 TYPE string.

    METHODS constructor
      IMPORTING textid    LIKE if_t100_message=>t100key         OPTIONAL
                attr1     TYPE string                           OPTIONAL
                attr2     TYPE string                           OPTIONAL
                attr3     TYPE string                           OPTIONAL
                attr4     TYPE string                           OPTIONAL
                !previous LIKE previous                         OPTIONAL
                severity  TYPE if_abap_behv_message=>t_severity OPTIONAL.

  PROTECTED SECTION.

  PRIVATE SECTION.
ENDCLASS.


CLASS zcx_merp_base IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    me->mv_attr1 = attr1.
    me->mv_attr2 = attr2.
    me->mv_attr3 = attr3.
    me->mv_attr4 = attr4.

    if_t100_dyn_msg~msgv1 = attr1.
    if_t100_dyn_msg~msgv2 = attr2.
    if_t100_dyn_msg~msgv3 = attr3.
    if_t100_dyn_msg~msgv4 = attr4.

    if_abap_behv_message~m_severity = COND #( WHEN severity IS NOT INITIAL
                                          THEN severity
                                          ELSE if_abap_behv_message=>severity-error ).

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
