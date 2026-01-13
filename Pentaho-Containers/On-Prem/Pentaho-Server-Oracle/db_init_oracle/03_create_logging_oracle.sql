-- =============================================================================
-- Pentaho Server 11 - Oracle Database Initialization
-- Script 3: Create Pentaho DI Logging Tables
-- =============================================================================
-- OLTP logging tables for Pentaho Data Integration
-- =============================================================================

-- Connect as hibuser (owns logging tables)
ALTER SESSION SET CURRENT_SCHEMA = hibuser;

-- -----------------------------------------------------------------------------
-- Job Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE job_logs (
    ID_JOB NUMBER(10),
    CHANNEL_ID VARCHAR2(255),
    JOBNAME VARCHAR2(255),
    STATUS VARCHAR2(15),
    LINES_READ NUMBER(19),
    LINES_WRITTEN NUMBER(19),
    LINES_UPDATED NUMBER(19),
    LINES_INPUT NUMBER(19),
    LINES_OUTPUT NUMBER(19),
    LINES_REJECTED NUMBER(19),
    ERRORS NUMBER(19),
    STARTDATE TIMESTAMP,
    ENDDATE TIMESTAMP,
    LOGDATE TIMESTAMP,
    DEPDATE TIMESTAMP,
    REPLAYDATE TIMESTAMP,
    LOG_FIELD CLOB,
    EXECUTING_SERVER VARCHAR2(255),
    EXECUTING_USER VARCHAR2(255),
    START_JOB_ENTRY VARCHAR2(255),
    CLIENT VARCHAR2(255)
);

CREATE INDEX IDX_job_logs_1 ON job_logs(ID_JOB);
CREATE INDEX IDX_job_logs_2 ON job_logs(ERRORS, STATUS, JOBNAME);

-- -----------------------------------------------------------------------------
-- Job Entry Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE jobentry_logs (
    ID_BATCH NUMBER(10),
    CHANNEL_ID VARCHAR2(255),
    LOG_DATE TIMESTAMP,
    TRANSNAME VARCHAR2(255),
    STEPNAME VARCHAR2(255),
    LINES_READ NUMBER(19),
    LINES_WRITTEN NUMBER(19),
    LINES_UPDATED NUMBER(19),
    LINES_INPUT NUMBER(19),
    LINES_OUTPUT NUMBER(19),
    LINES_REJECTED NUMBER(19),
    ERRORS NUMBER(19),
    RESULT CHAR(5),
    NR_RESULT_ROWS NUMBER(19),
    NR_RESULT_FILES NUMBER(19),
    LOG_FIELD CLOB,
    COPY_NR NUMBER(10)
);

CREATE INDEX IDX_jobentry_logs_1 ON jobentry_logs(ID_BATCH);

-- -----------------------------------------------------------------------------
-- Channel Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE channel_logs (
    ID_BATCH NUMBER(10),
    CHANNEL_ID VARCHAR2(255),
    LOG_DATE TIMESTAMP,
    LOGGING_OBJECT_TYPE VARCHAR2(255),
    OBJECT_NAME VARCHAR2(255),
    OBJECT_COPY VARCHAR2(255),
    REPOSITORY_DIRECTORY VARCHAR2(255),
    FILENAME VARCHAR2(255),
    OBJECT_ID VARCHAR2(255),
    OBJECT_REVISION VARCHAR2(255),
    PARENT_CHANNEL_ID VARCHAR2(255),
    ROOT_CHANNEL_ID VARCHAR2(255)
);

-- -----------------------------------------------------------------------------
-- Checkpoint Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE checkpoint_logs (
    ID_JOB_RUN NUMBER(10),
    ID_JOB NUMBER(10),
    JOBNAME VARCHAR2(255),
    NAMESPACE VARCHAR2(255),
    CHECKPOINT_NAME VARCHAR2(255),
    CHECKPOINT_COPYNR NUMBER(5),
    ATTEMPT_NR NUMBER(10),
    JOB_RUN_START_DATE TIMESTAMP,
    LOGDATE TIMESTAMP,
    RESULT_XML CLOB,
    PARAMETER_XML CLOB
);

CREATE INDEX IDX_checkpoint_logs_1 ON checkpoint_logs(ID_JOB_RUN);
CREATE INDEX IDX_checkpoint_logs_2 ON checkpoint_logs(JOBNAME, NAMESPACE);

-- -----------------------------------------------------------------------------
-- Transformation Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE trans_logs (
    ID_BATCH NUMBER(10),
    CHANNEL_ID VARCHAR2(255),
    TRANSNAME VARCHAR2(255),
    STATUS VARCHAR2(15),
    LINES_READ NUMBER(19),
    LINES_WRITTEN NUMBER(19),
    LINES_UPDATED NUMBER(19),
    LINES_INPUT NUMBER(19),
    LINES_OUTPUT NUMBER(19),
    LINES_REJECTED NUMBER(19),
    ERRORS NUMBER(19),
    STARTDATE TIMESTAMP,
    ENDDATE TIMESTAMP,
    LOGDATE TIMESTAMP,
    DEPDATE TIMESTAMP,
    REPLAYDATE TIMESTAMP,
    LOG_FIELD CLOB,
    EXECUTING_SERVER VARCHAR2(255),
    EXECUTING_USER VARCHAR2(255),
    CLIENT VARCHAR2(255)
);

CREATE INDEX IDX_trans_logs_1 ON trans_logs(ID_BATCH);
CREATE INDEX IDX_trans_logs_2 ON trans_logs(ERRORS, STATUS, TRANSNAME);

-- -----------------------------------------------------------------------------
-- Step Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE step_logs (
    ID_BATCH NUMBER(10),
    CHANNEL_ID VARCHAR2(255),
    LOG_DATE TIMESTAMP,
    TRANSNAME VARCHAR2(255),
    STEPNAME VARCHAR2(255),
    STEP_COPY NUMBER(5),
    LINES_READ NUMBER(19),
    LINES_WRITTEN NUMBER(19),
    LINES_UPDATED NUMBER(19),
    LINES_INPUT NUMBER(19),
    LINES_OUTPUT NUMBER(19),
    LINES_REJECTED NUMBER(19),
    ERRORS NUMBER(19),
    LOG_FIELD CLOB
);

-- -----------------------------------------------------------------------------
-- Transformation Performance Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE transperf_logs (
    ID_BATCH NUMBER(10),
    SEQ_NR NUMBER(10),
    LOGDATE TIMESTAMP,
    TRANSNAME VARCHAR2(255),
    STEPNAME VARCHAR2(255),
    STEP_COPY NUMBER(10),
    LINES_READ NUMBER(19),
    LINES_WRITTEN NUMBER(19),
    LINES_UPDATED NUMBER(19),
    LINES_INPUT NUMBER(19),
    LINES_OUTPUT NUMBER(19),
    LINES_REJECTED NUMBER(19),
    ERRORS NUMBER(19),
    INPUT_BUFFER_ROWS NUMBER(19),
    OUTPUT_BUFFER_ROWS NUMBER(19)
);

-- -----------------------------------------------------------------------------
-- Metrics Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE metrics_logs (
    ID_BATCH NUMBER(10),
    CHANNEL_ID VARCHAR2(255),
    LOG_DATE TIMESTAMP,
    METRICS_DATE TIMESTAMP,
    METRICS_CODE VARCHAR2(255),
    METRICS_DESCRIPTION VARCHAR2(255),
    METRICS_SUBJECT VARCHAR2(255),
    METRICS_TYPE VARCHAR2(255),
    METRICS_VALUE NUMBER(19)
);

COMMIT;
