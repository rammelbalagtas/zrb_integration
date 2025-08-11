CLASS zcl_call_iflow DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .

    TYPES:
      BEGIN OF oauth_token,
        access_token  TYPE string,
        token_type    TYPE string,
        id_token      TYPE string,
        refresh_token TYPE string,
        expires_in    TYPE i,
        scope         TYPE string,
        jti           TYPE string,
      END OF oauth_token.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA:
        out TYPE REF TO if_oo_adt_classrun_out.
    CLASS-METHODS:
      get_oauth_token IMPORTING VALUE(client_id)     TYPE string
                                VALUE(client_secret) TYPE string
                                VALUE(destination)   TYPE string
                      RETURNING VALUE(oauth_token)   TYPE  oauth_token,

      trigger_iflow  IMPORTING VALUE(iflow_endpoint) TYPE string
                               VALUE(oauth_token)    TYPE oauth_token
                     RETURNING VALUE(response)       TYPE string.
ENDCLASS.



CLASS zcl_call_iflow IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    TRY.
        DATA(client_id) = `b492425|it-rt-5aefca90trial!b55215`.
        DATA(client_secret) = `vuxU70bNwW7ONW0S7tnUnyiKoTuxdlGymKzLA=`.
        DATA(destination) = `https://5aefca90trial.authentication.us10.hana.ondemand.com/oauth/token`.
        DATA(iflow_endpoint) = `https://5aefca90trial.it-cpitrial06-rt.cfapps.us10-001.hana.ondemand.com/http/transmission/inbound`.
        DATA(oauth_token) = get_oauth_token(  client_id = client_id
                                              client_secret = client_secret
                                              destination = destination
                                           ).
        IF oauth_token IS NOT INITIAL.
          DATA(iflow_response) =   trigger_iflow( oauth_token = oauth_token
                                                  iflow_endpoint = iflow_endpoint
                                                ).
          out->write( iflow_response )   .
        ENDIF.
      CATCH cx_web_http_client_error
                   cx_http_dest_provider_error INTO DATA(exception).
        out->write( exception->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_oauth_token.
    DATA(dest) = cl_http_destination_provider=>create_by_url( destination ).
    DATA(http_client) = cl_web_http_client_manager=>create_by_http_destination( dest ).
    DATA(request) = http_client->get_http_request( ).

    DATA(body_request) = `grant_type=client_credentials`.
    request->append_text( body_request ).

    request->set_header_fields( VALUE #(
      ( name = 'Content-Type'
        value = 'application/x-www-form-urlencoded' )
      ( name = 'Accept'  value = 'application/json' ) ) ).

    request->set_authorization_basic(
                  i_username = client_id
                  i_password = client_secret
                  ).

    DATA(token) = http_client->execute( if_web_http_client=>post ).

    /ui2/cl_json=>deserialize(
     EXPORTING
       json = token->get_text( )
     CHANGING
       data = oauth_token
      ).
  ENDMETHOD.

  METHOD trigger_iflow.

    DATA(dest) = cl_http_destination_provider=>create_by_url( iflow_endpoint ).
    DATA(http_client) = cl_web_http_client_manager=>create_by_http_destination( dest ).
    DATA(request) = http_client->get_http_request( ).

    DATA(bearer) = |Bearer { oauth_token-access_token }|.
    request->set_header_field(
          i_name  = 'Authorization'
          i_value = bearer ).

    request->set_header_fields( VALUE #(
       ( name = 'Content-Type'
         value = 'application/xml' )
       ( name = 'Accept'  value = '*/*' ) ) ).

    DATA lt_table TYPE TABLE OF string.

    APPEND INITIAL LINE TO lt_table ASSIGNING FIELD-SYMBOL(<fs_string>).
    <fs_string> = `<?xml version='1.0' encoding='UTF-8' ?>`.
    APPEND INITIAL LINE TO lt_table ASSIGNING <fs_string>.
    <fs_string> = `<request>`.
    APPEND INITIAL LINE TO lt_table ASSIGNING <fs_string>.
    <fs_string> = `<sftp>`.
    APPEND INITIAL LINE TO lt_table ASSIGNING <fs_string>.
    <fs_string> = `<Directory>/Root/Inbound</Directory>`.
    APPEND INITIAL LINE TO lt_table ASSIGNING <fs_string>.
    <fs_string> = `<File>inputfile123.txt</File>`.
    APPEND INITIAL LINE TO lt_table ASSIGNING <fs_string>.
    <fs_string> = `</sftp>`.
    APPEND INITIAL LINE TO lt_table ASSIGNING <fs_string>.
    <fs_string> = `</request>`.

    CONCATENATE LINES OF lt_table INTO DATA(lv_string) SEPARATED BY cl_abap_char_utilities=>cr_lf.

    DATA(body_request) = lv_string.
    request->append_text( body_request ).

    DATA(resp) = http_client->execute( if_web_http_client=>post ).
    response = resp->get_text(   ).

  ENDMETHOD.

ENDCLASS.
