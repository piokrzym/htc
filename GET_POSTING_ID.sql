--------------------------------------------------------
--  File created - Saturday-October-08-2016   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Procedure GET_POSTING_ID
--------------------------------------------------------
set define off;

  CREATE OR REPLACE PROCEDURE "RAVEN"."GET_POSTING_ID" (in_station varchar2,
                                            in_system varchar2,
                                            out_posting_id out nocopy varchar2,
                                            out_status out nocopy number)
IS 
  c_oracle_system    CONSTANT VARCHAR2(1)  := 'O';
  c_error_status     CONSTANT VARCHAR2(3)  := 'ERR'; 
  c_oky_status       CONSTANT VARCHAR2(3)  := 'OKY';
  c_err_status       CONSTANT NUMBER(1,0)  := 1;
  c_ok_status        CONSTANT NUMBER(1,0)  := 0;
 
c_procedure   CONSTANT OTCTB_SAP_INVOICE_LOG.SAP_PROCEDURE%TYPE := 'GET_POSTING_ID';
    l_param_xml   OTCTB_SAP_INVOICE_LOG.INPUT_PARAMETERS%TYPE;
    l_log_id      OTCTB_SAP_INVOICE_LOG.SAP_LOG_ID%TYPE;
    l_system      OTCTB_SAP_INVOICE_LOG.SAP_SYSTEM%TYPE;
    
    PROCEDURE are_station_and_system_exist 
    IS
      l_are_parameters_correct  VARCHAR2(5);
    BEGIN
      IF (IN_STATION IS NULL or IN_SYSTEM IS NULL) THEN raise no_data_found; END IF;   
      SELECT CASE WHEN EXISTS (SELECT 1 FROM otctb_sap_invoice_admin t 
                               WHERE t.internal_key='OTC_POSTING_ID'
                                 AND t.internal_station=IN_STATION
                                 AND t.internal_system=IN_SYSTEM) THEN 'TRUE'
                  ELSE 'FALSE' END
                  INTO l_are_parameters_correct FROM dual;
      IF l_are_parameters_correct = 'FALSE' THEN raise no_data_found; END IF;      
    END are_station_and_system_exist;
    
    PROCEDURE generate_posting_id (posting_id_IN_OUT IN OUT NOCOPY VARCHAR2)
    IS
      sap_id NUMBER(14,0);
    BEGIN
      SELECT SUBSTR (LAST_POSTING_ID,2,14) + 1 INTO sap_id FROM OTCTB_SAP_INVOICE_ADMIN 
      WHERE INTERNAL_KEY = 'OTC_POSTING_ID'
        AND INTERNAL_SYSTEM = IN_SYSTEM
        AND INTERNAL_STATION = IN_STATION
        AND SUBSTR (LAST_POSTING_ID,2,14) + 1 >= range_from
        AND SUBSTR (LAST_POSTING_ID,2,14) + 1 <= range_to
        FOR UPDATE;
        
      posting_id_IN_OUT := IN_STATION || LPAD(sap_id,14,0);
      
      UPDATE OTCTB_SAP_INVOICE_ADMIN SET LAST_POSTING_ID = posting_id_IN_OUT
        WHERE INTERNAL_KEY = 'OTC_POSTING_ID'
          AND INTERNAL_SYSTEM = IN_SYSTEM
          AND INTERNAL_STATION = IN_STATION;
      commit;          
    EXCEPTION
      when others
        then rollback;
        raise;
    END generate_posting_id; 
    
  BEGIN
    OUT_STATUS      := c_err_status; 
    OUT_POSTING_ID  := '0';
    l_system        := NVL (IN_SYSTEM, c_oracle_system);
    l_param_xml     := 'parameters'; 
    
    are_station_and_system_exist;
    generate_posting_id (OUT_POSTING_ID);
    
    OUT_STATUS      := c_ok_status;
    insert_log (OUT_POSTING_ID, c_procedure, l_system, l_param_xml, c_oky_status, sap_log_id_out => l_log_id);	 
  EXCEPTION 
    WHEN no_data_found THEN 
      insert_log (OUT_POSTING_ID, c_procedure, l_system, l_param_xml, c_error_status
                            ,'Could not obtain SAP_ID for this STATION. Check input parameters.'
                            ,sap_log_id_out => l_log_id);
    WHEN others THEN
      insert_log (OUT_POSTING_ID, c_procedure, l_system, l_param_xml, c_error_status
                            ,SUBSTR ('ERROR'                      || CHR(10) || ' ' ||
                                     dbms_utility.format_error_stack       ||
                                     dbms_utility.format_error_backtrace   ,0, 2000), sap_log_id_out => l_log_id);
  END get_POSTING_ID;

/
