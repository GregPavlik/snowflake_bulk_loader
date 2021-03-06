-- Worksheet 03.Bulk Load - Set/Reset
-- Last modified 2020-04-17

/****************************************************************************************************
*                                                                                                   *
*  This script sets and resets the control table and target table.                                  *
*  Click on the "All Queries" checkbox and run all statements to reset unit tests.                  *
*                                                                                                   * 
*  This script *is* possibly useful for production environments. If the LIST command does not       *
*  time out, you can use the LIST command here to populate the control table.                       *
*                                                                                                   *
****************************************************************************************************/


/****************************************************************************************************
*                                                                                                   *
*  Convert the last modified value from the Snowflake LIST command into a timestamp.                *
*                                                                                                   *
****************************************************************************************************/
create or replace function LAST_MODIFIED_TO_TIMESTAMP(LAST_MODIFIED string) 
returns timestamp_tz
as
$$
    to_timestamp_tz(left(LAST_MODIFIED, len(LAST_MODIFIED) - 4) || ' ' || '00:00', 'DY, DD MON YYYY HH:MI:SS TZH:TZM')
$$;

/****************************************************************************************************
*                                                                                                   *
*  Create a sample table for testing. Skip if this is a production use of the project.              *
*                                                                                                   *
****************************************************************************************************/
create or replace table TARGET_TABLE like "SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1000"."ORDERS";


/****************************************************************************************************
*                                                                                                   *
*  Reset the control table if it's already been created.                                            *
*                                                                                                   *
****************************************************************************************************/
truncate table if exists FILE_INGEST_CONTROL;
   
   
/****************************************************************************************************
*                                                                                                   *
*  This section populates the control table. It uses the stage LIST to fill the control table.      *
*  This section *is* useful in a production environment if the LIST command returns (does not       *
*  time out) and returns the file list you need.                                                    *
*                                                                                                   *
****************************************************************************************************/   
list @TEST_STAGE/TPCH/;

insert into FILE_INGEST_CONTROL
    (FILE_PATH, INGESTION_ORDER, FILE_SIZE) 
    select 
        "name", 
        LAST_MODIFIED_TO_TIMESTAMP("last_modified"),
        "size"
from table(result_scan(last_query_id()));

-- Review the control table to see how it looks:
select * from FILE_INGEST_CONTROL order by INGESTION_ORDER asc limit 10;

-- Recommended values for FILE_TO_PROCESS and FILES_AT_ONCE
with
PARAMS(WAREHOUSE_SIZE, CORES, FILES_TO_PROCESS, AVG_MB, FILES_AT_ONCE)
as
(
select  'Small'                                             as WAREHOUSE_SIZE,     --Change to the size you plan to use
        nodes_per_warehouse(WAREHOUSE_SIZE) * 8             as CORES,
        count(*)                                            as FILES_TO_PROCESS,
        avg(FILE_SIZE)/1000000                              as AVG_MB,  
        ceil((512 / AVG_MB) / CORES) * CORES                as FILES_AT_ONCE
from    FILE_INGEST_CONTROL
)
select  FILES_TO_PROCESS, FILES_AT_ONCE
from    PARAMS;
  
/****************************************************************************************************
*                                                                                                   *
* Calculate file size consistency and maximum recommended warhouse size for each running            *
* FileIngest stored procedure. NOTE: X-Small warehouses are always the most efficient option.       *
*                                                                                                   *
* This section *is* useful in production to determine the maximum recommended warehouse size.       *
* You can run the stored procedure on as many warehouses as you want up to the max recommended      *
* size for each warehouse. The max recommended size depends on the consistency of the file size.    *
*                                                                                                   *
****************************************************************************************************/
with 
    FILE_STATS (AVG_FILE_SIZE) as
    (
        select
        avg(FILE_SIZE)  as AVG_SIZE
        from            FILE_INGEST_CONTROL
    )
select  sum(case when FILE_SIZE / S.AVG_FILE_SIZE < 0.50 then 1 else 0 end) / count(*) * 100    as PERCENT_ABNORMALLY_SMALL_FILES,
        sum(case when FILE_SIZE / S.AVG_FILE_SIZE > 2.00 then 1 else 0 end) / count(*) * 100    as PERCENT_ABNORMALLY_LARGE_FILES,
        (100 - PERCENT_ABNORMALLY_SMALL_FILES) - PERCENT_ABNORMALLY_LARGE_FILES                 as PERCENT_AVERAGE_SIZE_FILES,
        case
            when PERCENT_AVERAGE_SIZE_FILES >= 95 and PERCENT_ABNORMALLY_LARGE_FILES < 0.5 then 'Medium'
            when PERCENT_AVERAGE_SIZE_FILES >= 90 and PERCENT_ABNORMALLY_LARGE_FILES < 1.0 then 'Small'
            else                                                                                'X-Small'
        end                                                                                     as MAX_RECOMMENDED_WAREHOUSE_SIZE
from    FILE_INGEST_CONTROL C, FILE_STATS S;
