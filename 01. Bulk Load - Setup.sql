-- Worksheet 01.Bulk Load - Setup
-- Last modified 2020-04-17

/****************************************************************************************************
*                                                                                                   *
*  This worksheet creates an internal stage and fills it with data from SNOWFLAKE_SAMPLE_DATA.      *
*  For the purposes of the control table and stored procedure, an internal stage will               *
*  work the same way as an external one.                                                            *
*                                                                                                   *
*  ==> Run this worksheet only once. It doesn't need re-running when resetting the environment.     *
*                                                                                                   *
*  ==> This script uses a warehouse named TEST, but no code requires this name,                     *
*      If you want to use a different warehouse, you will need to change the name                   *
*      in the SQL script.                                                                           *
*                                                                                                   *
****************************************************************************************************/

/****************************************************************************************************
*                                                                                                   *
*  Run this top part to create a progress bar for the "05. Bulk Load - Monitor" worksheet.          *
*                                                                                                   *
****************************************************************************************************/

create or replace function PROGRESS_BAR(PERCENTAGE float, DECIMALS float, SEGMENTS float)
returns string
language javascript
as
$$

    var percent = PERCENTAGE;
    
    if (isNaN(percent)) percent =   0;
    if (percent < 0)    percent =   0;
    if (percent > 100)  percent = 100;

    percent        = percent.toFixed(DECIMALS);

    var filledSegments = Math.round(SEGMENTS * (percent / 100));
    var emptySegments  = SEGMENTS - filledSegments;

    var bar = '⬛'.repeat(filledSegments) + '⬜'.repeat(emptySegments);
 
    return bar + " " + percent + "%";

$$;
 
-- This is an overload with only the percentage, using defaults for 
-- number of segments and decimal points to display on percentage.
create or replace function PROGRESS_BAR(PERCENTAGE float)
returns string
language sql
as
$$
    select progress_bar(PERCENTAGE, 2, 10)
$$;
 
-- This is an overload with the percentage and the option set for the
-- number of decimals to display. It uses a default for number of segments.
create or replace function PROGRESS_BAR(PERCENTAGE float, DECIMALS float)
returns string
language sql
as
$$
    select progress_bar(PERCENTAGE, DECIMALS, 10)
$$;

-- Returns the number of nodes for a given named cluster size
create or replace function NODES_PER_WAREHOUSE(WAREHOUSE_SIZE string)
returns integer
language SQL
as
$$
    case upper(WAREHOUSE_SIZE)
        when 'X-SMALL'  then 1
        when 'XS'       then 1
        when 'SMALL'    then 2
        when 'S'        then 2
        when 'MEDIUM'   then 4
        when 'M'        then 4
        when 'LARGE'    then 8
        when 'L'        then 8
        when 'X-LARGE'  then 16
        when 'XL'       then 16
        when '2X-LARGE' then 32
        when '2XL'      then 32
        when '3X-LARGE' then 64
        when '3XL'      then 64
        when '4X-LARGE' then 128
        when '4XL'      then 128
        else            null
    end
$$;

/****************************************************************************************************
*                                                                                                   *
*  Run this lower part only to create a some sample data for testing. You do not need to run this   *
*  if you have another stage data to use. You do not need to run this more than once. To reset the  *
*  test environment, run all statements in the "03. Bulk Load - Set/Reset" worksheet.               *
*                                                                                                   *
*  NOTE: If you do not see a SAMPLE_DATA database, it may be named something else. If you don't     *
*        have one at all, you can import the shared database from SFC_SAMPLES. Click on the Shares  *
*        button on the ribbon bar to import the database.                                           *
*                                                                                                   *
*  Delete the first to characters /* on line 109 and execute SQL to load sample data.               *
*                                                                                                   *
****************************************************************************************************/

/*  -- Delete the /* here and execute SQL below here to load sample data.

-- Copy 1.5 billion rows from Snowflake's sample data to a stage:
use role ACCOUNTADMIN;
drop table if exists TARGET_TABLE;
create or replace stage TEST_STAGE;
grant all privileges on stage TEST_STAGE to SYSADMIN;
use role SYSADMIN;

-- NOTE: Not all Snowflake accounts have the same names for sample data. Adjust as required.
select to_varchar(count(*), '999,999,999,999,999,999') as ROW_COUNT from "SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1000"."ORDERS";

-- Copy data into CSV files in an internal stage:
alter warehouse "TEST" set warehouse_size = 'XXLARGE';
copy into @TEST_STAGE/TPCH/ from "SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1000"."ORDERS";  -- Takes ~0:01:00 minute on 2XL
alter WAREHOUSE "TEST" set warehouse_size = 'XSMALL';

-- Send status message:
select 'Test data staged for bulk load utility.' as STATUS;

-- */  
