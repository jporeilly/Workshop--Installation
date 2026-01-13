-- =============================================================================
-- Pentaho Server 11 - Oracle Database Initialization
-- Script 4: Create Pentaho Operations Mart Tables
-- =============================================================================
-- Data warehouse tables for Pentaho Operations Analytics
-- =============================================================================

-- Connect as hibuser (owns mart tables)
ALTER SESSION SET CURRENT_SCHEMA = hibuser;

-- -----------------------------------------------------------------------------
-- Dimension Tables
-- -----------------------------------------------------------------------------

-- Batch Dimension
CREATE TABLE dim_batch (
    batch_tk NUMBER(19) NOT NULL,
    batch_id NUMBER(19),
    logchannel_id VARCHAR2(100),
    parent_logchannel_id VARCHAR2(100),
    CONSTRAINT PK_dim_batch PRIMARY KEY (batch_tk)
);
CREATE INDEX IDX_dim_batch_LOOKUP ON dim_batch(batch_id, logchannel_id, parent_logchannel_id);

-- Date Dimension
CREATE TABLE dim_date (
    date_tk NUMBER(10) NOT NULL,
    date_field TIMESTAMP,
    ymd VARCHAR2(10),
    ym VARCHAR2(7),
    year NUMBER(10),
    quarter NUMBER(10),
    quarter_code VARCHAR2(2),
    month NUMBER(10),
    month_desc VARCHAR2(20),
    month_code VARCHAR2(15),
    day NUMBER(10),
    day_of_year NUMBER(10),
    day_of_week NUMBER(10),
    day_of_week_desc VARCHAR2(20),
    day_of_week_code VARCHAR2(15),
    week NUMBER(10),
    CONSTRAINT PK_dim_date PRIMARY KEY (date_tk)
);

-- Execution Dimension
CREATE TABLE dim_execution (
    execution_tk NUMBER(19) NOT NULL,
    execution_id VARCHAR2(100),
    server_host VARCHAR2(100),
    executing_user VARCHAR2(100),
    execution_status VARCHAR2(30),
    client VARCHAR2(255),
    CONSTRAINT PK_dim_execution PRIMARY KEY (execution_tk)
);
CREATE INDEX IDX_dim_execution_LOOKUP ON dim_execution(execution_id, server_host, executing_user, client);

-- Executor Dimension
CREATE TABLE dim_executor (
    executor_tk NUMBER(19) NOT NULL,
    version NUMBER(10),
    date_from TIMESTAMP,
    date_to TIMESTAMP,
    executor_id VARCHAR2(255),
    executor_source VARCHAR2(255),
    executor_environment VARCHAR2(255),
    executor_type VARCHAR2(255),
    executor_name VARCHAR2(255),
    executor_desc VARCHAR2(255),
    executor_revision VARCHAR2(255),
    executor_version_label VARCHAR2(255),
    exec_enabled_table_logging CHAR(1),
    exec_enabled_detailed_logging CHAR(1),
    exec_enabled_perf_logging CHAR(1),
    exec_enabled_history_logging CHAR(1),
    last_updated_date TIMESTAMP,
    last_updated_user VARCHAR2(255),
    CONSTRAINT PK_dim_executor PRIMARY KEY (executor_tk)
);
CREATE INDEX IDX_dim_executor_LOOKUP ON dim_executor(executor_id);

-- Time Dimension
CREATE TABLE dim_time (
    time_tk NUMBER(10) NOT NULL,
    hms VARCHAR2(8),
    hm VARCHAR2(5),
    ampm VARCHAR2(8),
    hour NUMBER(10),
    hour12 NUMBER(10),
    minute NUMBER(10),
    second NUMBER(10),
    CONSTRAINT PK_dim_time PRIMARY KEY (time_tk)
);

-- Log Table Dimension
CREATE TABLE dim_log_table (
    log_table_tk NUMBER(19) NOT NULL,
    object_type VARCHAR2(30),
    table_connection_name VARCHAR2(255),
    table_name VARCHAR2(255),
    schema_name VARCHAR2(255),
    step_entry_table_conn_name VARCHAR2(255),
    step_entry_table_name VARCHAR2(255),
    step_entry_schema_name VARCHAR2(255),
    perf_table_conn_name VARCHAR2(255),
    perf_table_name VARCHAR2(255),
    perf_schema_name VARCHAR2(255),
    CONSTRAINT PK_dim_log_table PRIMARY KEY (log_table_tk)
);
CREATE INDEX IDX_dim_log_table_lookup ON dim_log_table(object_type, table_connection_name, table_name, schema_name);

-- Step Dimension
CREATE TABLE dim_step (
    step_tk NUMBER(19) NOT NULL,
    step_id VARCHAR2(255),
    original_step_name VARCHAR2(255),
    CONSTRAINT PK_dim_step PRIMARY KEY (step_tk)
);
CREATE INDEX IDX_dim_step_lookup ON dim_step(step_id);

-- State Dimension
CREATE TABLE dim_state (
    state_tk NUMBER(19) NOT NULL,
    state VARCHAR2(100) NOT NULL,
    CONSTRAINT PK_dim_state PRIMARY KEY (state_tk)
);

-- Session Dimension
CREATE TABLE dim_session (
    session_tk NUMBER(19) NOT NULL,
    session_id VARCHAR2(200) NOT NULL,
    session_type VARCHAR2(200) NOT NULL,
    username VARCHAR2(200) NOT NULL,
    CONSTRAINT PK_dim_session PRIMARY KEY (session_tk)
);

-- Instance Dimension
CREATE TABLE dim_instance (
    instance_tk NUMBER(19) NOT NULL,
    instance_id VARCHAR2(200) NOT NULL,
    engine_id VARCHAR2(200) NOT NULL,
    service_id VARCHAR2(200) NOT NULL,
    content_id VARCHAR2(1024) NOT NULL,
    content_detail VARCHAR2(1024),
    CONSTRAINT PK_dim_instance PRIMARY KEY (instance_tk)
);

-- Component Dimension
CREATE TABLE dim_component (
    component_tk NUMBER(19) NOT NULL,
    component_id VARCHAR2(200) NOT NULL,
    CONSTRAINT PK_dim_component PRIMARY KEY (component_tk)
);

-- Content Item Dimension
CREATE TABLE dim_content_item (
    content_item_tk NUMBER(10) NOT NULL,
    content_item_title VARCHAR2(255) DEFAULT 'NA' NOT NULL,
    content_item_locale VARCHAR2(255) DEFAULT 'NA' NOT NULL,
    content_item_size NUMBER(10) DEFAULT 0 NOT NULL,
    content_item_path VARCHAR2(1024) DEFAULT 'NA' NOT NULL,
    content_item_name VARCHAR2(255) DEFAULT 'NA' NOT NULL,
    content_item_fullname VARCHAR2(1024) DEFAULT 'NA' NOT NULL,
    content_item_type VARCHAR2(32) DEFAULT 'NA' NOT NULL,
    content_item_extension VARCHAR2(32) DEFAULT 'NA' NOT NULL,
    content_item_guid CHAR(36) DEFAULT 'NA' NOT NULL,
    parent_content_item_guid CHAR(36) DEFAULT 'NA',
    parent_content_item_tk NUMBER(10),
    content_item_modified TIMESTAMP DEFAULT TO_TIMESTAMP('1900-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') NOT NULL,
    content_item_valid_from TIMESTAMP DEFAULT TO_TIMESTAMP('1900-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') NOT NULL,
    content_item_valid_to TIMESTAMP DEFAULT TO_TIMESTAMP('9999-12-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS') NOT NULL,
    content_item_state VARCHAR2(16) DEFAULT 'new' NOT NULL,
    content_item_version NUMBER(10) DEFAULT 0 NOT NULL,
    CONSTRAINT PK_dim_content_item PRIMARY KEY (content_item_tk)
);
CREATE INDEX IDX_dim_content_item_guid ON dim_content_item(content_item_guid, content_item_valid_from);

-- -----------------------------------------------------------------------------
-- Fact Tables
-- -----------------------------------------------------------------------------

-- Execution Fact
CREATE TABLE fact_execution (
    execution_date_tk NUMBER(10),
    execution_time_tk NUMBER(10),
    batch_tk NUMBER(10),
    execution_tk NUMBER(10),
    executor_tk NUMBER(10),
    parent_executor_tk NUMBER(10),
    root_executor_tk NUMBER(10),
    execution_timestamp TIMESTAMP,
    duration NUMBER,
    rows_input NUMBER(10),
    rows_output NUMBER(10),
    rows_read NUMBER(10),
    rows_written NUMBER(10),
    rows_rejected NUMBER(10),
    errors NUMBER(10),
    failed NUMBER(1)
);
CREATE INDEX IDX_fact_exec_DATE_TK ON fact_execution(execution_date_tk);
CREATE INDEX IDX_fact_exec_TIME_TK ON fact_execution(execution_time_tk);
CREATE INDEX IDX_fact_exec_BATCH_TK ON fact_execution(batch_tk);
CREATE INDEX IDX_fact_exec_EXEC_TK ON fact_execution(execution_tk);
CREATE INDEX IDX_fact_exec_EXECUTOR_TK ON fact_execution(executor_tk);

-- Step Execution Fact
CREATE TABLE fact_step_execution (
    execution_date_tk NUMBER(10),
    execution_time_tk NUMBER(10),
    batch_tk NUMBER(10),
    executor_tk NUMBER(10),
    parent_executor_tk NUMBER(10),
    root_executor_tk NUMBER(10),
    step_tk NUMBER(10),
    step_copy NUMBER(10),
    execution_timestamp TIMESTAMP,
    rows_input NUMBER(10),
    rows_output NUMBER(10),
    rows_read NUMBER(10),
    rows_written NUMBER(10),
    rows_rejected NUMBER(10),
    errors NUMBER(10)
);
CREATE INDEX IDX_fact_step_DATE_TK ON fact_step_execution(execution_date_tk);
CREATE INDEX IDX_fact_step_BATCH_TK ON fact_step_execution(batch_tk);
CREATE INDEX IDX_fact_step_EXECUTOR_TK ON fact_step_execution(executor_tk);
CREATE INDEX IDX_fact_step_STEP_TK ON fact_step_execution(step_tk);

-- Job Entry Execution Fact
CREATE TABLE fact_jobentry_execution (
    execution_date_tk NUMBER(10),
    execution_time_tk NUMBER(10),
    batch_tk NUMBER(10),
    executor_tk NUMBER(10),
    parent_executor_tk NUMBER(10),
    root_executor_tk NUMBER(10),
    step_tk NUMBER(10),
    execution_timestamp TIMESTAMP,
    rows_input NUMBER(10),
    rows_output NUMBER(10),
    rows_read NUMBER(10),
    rows_written NUMBER(10),
    rows_rejected NUMBER(10),
    errors NUMBER(10),
    result CHAR(1),
    nr_result_rows NUMBER(10),
    nr_result_files NUMBER(10)
);
CREATE INDEX IDX_fact_jobentry_DATE_TK ON fact_jobentry_execution(execution_date_tk);
CREATE INDEX IDX_fact_jobentry_BATCH_TK ON fact_jobentry_execution(batch_tk);
CREATE INDEX IDX_fact_jobentry_EXECUTOR_TK ON fact_jobentry_execution(executor_tk);

-- Performance Execution Fact
CREATE TABLE fact_perf_execution (
    execution_date_tk NUMBER(10),
    execution_time_tk NUMBER(10),
    batch_tk NUMBER(10),
    executor_tk NUMBER(10),
    parent_executor_tk NUMBER(10),
    root_executor_tk NUMBER(10),
    step_tk NUMBER(10),
    seq_nr NUMBER(10),
    step_copy NUMBER(10),
    execution_timestamp TIMESTAMP,
    rows_input NUMBER(10),
    rows_output NUMBER(10),
    rows_read NUMBER(10),
    rows_written NUMBER(10),
    rows_rejected NUMBER(10),
    errors NUMBER(10),
    input_buffer_rows NUMBER(10),
    output_buffer_rows NUMBER(10)
);
CREATE INDEX IDX_fact_perf_DATE_TK ON fact_perf_execution(execution_date_tk);
CREATE INDEX IDX_fact_perf_BATCH_TK ON fact_perf_execution(batch_tk);
CREATE INDEX IDX_fact_perf_EXECUTOR_TK ON fact_perf_execution(executor_tk);
CREATE INDEX IDX_fact_perf_STEP_TK ON fact_perf_execution(step_tk);

-- Session Fact
CREATE TABLE fact_session (
    start_date_tk NUMBER(10) NOT NULL,
    start_time_tk NUMBER(10) NOT NULL,
    end_date_tk NUMBER(10) NOT NULL,
    end_time_tk NUMBER(10) NOT NULL,
    session_tk NUMBER(19) NOT NULL,
    state_tk NUMBER(19) NOT NULL,
    duration NUMBER(19,3) NOT NULL
);
CREATE INDEX IDX_fact_session_START_DATE ON fact_session(start_date_tk);
CREATE INDEX IDX_fact_session_SESSION_TK ON fact_session(session_tk);
CREATE INDEX IDX_fact_session_STATE_TK ON fact_session(state_tk);

-- Instance Fact
CREATE TABLE fact_instance (
    start_date_tk NUMBER(10) NOT NULL,
    start_time_tk NUMBER(10) NOT NULL,
    end_date_tk NUMBER(10) NOT NULL,
    end_time_tk NUMBER(10) NOT NULL,
    session_tk NUMBER(19) NOT NULL,
    instance_tk NUMBER(19) NOT NULL,
    state_tk NUMBER(19) NOT NULL,
    duration NUMBER(19,3) NOT NULL
);
CREATE INDEX IDX_fact_instance_START_DATE ON fact_instance(start_date_tk);
CREATE INDEX IDX_fact_instance_SESSION_TK ON fact_instance(session_tk);
CREATE INDEX IDX_fact_instance_INSTANCE_TK ON fact_instance(instance_tk);

-- Component Fact
CREATE TABLE fact_component (
    start_date_tk NUMBER(10) NOT NULL,
    start_time_tk NUMBER(10) NOT NULL,
    end_date_tk NUMBER(10) NOT NULL,
    end_time_tk NUMBER(10) NOT NULL,
    session_tk NUMBER(19) NOT NULL,
    instance_tk NUMBER(19) NOT NULL,
    state_tk NUMBER(19) NOT NULL,
    component_tk NUMBER(19) NOT NULL,
    duration NUMBER(19,3) NOT NULL
);
CREATE INDEX IDX_fact_component_START_DATE ON fact_component(start_date_tk);
CREATE INDEX IDX_fact_component_SESSION_TK ON fact_component(session_tk);
CREATE INDEX IDX_fact_component_COMPONENT_TK ON fact_component(component_tk);

-- -----------------------------------------------------------------------------
-- Staging Tables
-- -----------------------------------------------------------------------------

-- Content Item Staging
CREATE TABLE stg_content_item (
    gid CHAR(36) NOT NULL,
    parent_gid CHAR(36),
    fileSize NUMBER(10) NOT NULL,
    locale VARCHAR2(5),
    name VARCHAR2(200) NOT NULL,
    ownerType NUMBER(3) NOT NULL,
    path VARCHAR2(1024) NOT NULL,
    title VARCHAR2(255),
    is_folder CHAR(1) NOT NULL,
    is_hidden CHAR(1) NOT NULL,
    is_locked CHAR(1) NOT NULL,
    is_versioned CHAR(1) NOT NULL,
    date_created TIMESTAMP,
    date_last_modified TIMESTAMP,
    is_processed CHAR(1),
    CONSTRAINT PK_stg_content_item PRIMARY KEY (gid)
);
CREATE INDEX IDX_stg_content_item_parent ON stg_content_item(parent_gid);

-- Pro Audit Staging
CREATE TABLE pro_audit_staging (
    job_id VARCHAR2(200),
    inst_id VARCHAR2(200),
    obj_id VARCHAR2(1024),
    obj_type VARCHAR2(200),
    actor VARCHAR2(200),
    message_type VARCHAR2(200),
    message_name VARCHAR2(200),
    message_text_value VARCHAR2(1024),
    message_num_value NUMBER(19),
    duration NUMBER(19,3),
    audit_time TIMESTAMP
);
CREATE INDEX IDX_pro_audit_staging_type ON pro_audit_staging(message_type);

-- Pro Audit Tracker
CREATE TABLE pro_audit_tracker (
    audit_time TIMESTAMP
);
CREATE INDEX IDX_pro_audit_tracker_time ON pro_audit_tracker(audit_time);

INSERT INTO pro_audit_tracker VALUES (TO_TIMESTAMP('1970-01-01 00:00:01', 'YYYY-MM-DD HH24:MI:SS'));

COMMIT;
