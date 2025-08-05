# Performance Tuning and Automated Maintenance for SQL Server

## Introduction

You work at CarvedRock, a growing e-commerce company. The database team has reported slow query performance and needs to implement automated maintenance. You'll diagnose performance issues and set up automated tasks to keep the database healthy.

## Solution

### Getting Started in the Lab Environment

Welcome! This lab provides you with a Windows Server environment with SQL Server 2019 installed. The CarvedRock database has been pre-created with sample data and intentional performance issues for you to diagnose and fix.

**Lab Environment Details:**
- Windows Server 2022 with SQL Server 2019 Developer Edition
- SQL Server Management Studio (SSMS) pre-installed
- Username: `cloud_user`
- Password: `P@ssw0rd123456!`

#### Connecting to Your Lab VM

1. In the Azure portal, you should see your resource group with the VM named **sqlLabVM**. Click on the **sqlLabVM** resource.

2. On the VM overview page, click the **Connect** button in the top menu bar.

3. In the Connect panel that opens:
   - Verify the **Public IP address** is shown (it should be something like `13.83.81.35`)
   - The **Admin username** should show `cloud_user`
   - The **Port** should be `3389`

4. Under **Native RDP**, click the **Download RDP file** button. This will download a file named `sqlLabVM.rdp` to your computer.

5. Open the downloaded RDP file:
   - On Windows: Double-click the file
   - On Mac: Open with Microsoft Remote Desktop app (install from App Store if needed)
   - On Linux: Open with an RDP client like Remmina

6. When prompted for credentials:
   - **Username**: Try one of these formats:
     - `.\cloud_user` (with the dot and backslash prefix for local account)
     - `cloud_user` (without domain)
     - `sqlLabVM\cloud_user` (with VM name as domain)
   - **Password**: `P@ssw0rd123456!`
   - Click **OK** or **Connect**
   
   **If login fails**:
   - Make sure you're using the exact password with correct capitalization
   - Try the username with `.\` prefix: `.\cloud_user`
   - Check if Caps Lock is on

7. You may see a certificate warning. This is normal for lab environments. Click **Yes** or **Continue** to proceed.

8. Once connected, you'll see the Windows Server desktop. SQL Server 2019 and SSMS are already installed.

#### Starting SQL Server Management Studio

1. When you first connect via RDP, **Server Manager** will open automatically. You can minimize or close this window - it's not needed for the lab.

2. To find SQL Server Management Studio:
   - Click the **Start** button (Windows icon) in the bottom-left corner
   - Type `ssms` in the search box
   - You should see **Microsoft SQL Server Management Studio 18** appear
   - If not found, try:
     - Look for it in **Start** > **All Programs** > **Microsoft SQL Server Tools 18**
     - Or navigate to `C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\` and run `Ssms.exe`
   
   **If SSMS is not installed**:
   - Check if `C:\LabScripts\SSMS-Setup.exe` exists
   - If yes, run it to install SSMS (takes 5-10 minutes)
   - If no, download from: https://aka.ms/ssmsfullsetup
   - After installation, SSMS will appear in the Start menu

3. Click to open **SQL Server Management Studio 18**. It may take 10-20 seconds to load the first time.

4. In the **Connect to Server** dialog that appears:
   - **Server type**: Database Engine
   - **Server name**: `.` (just type a single period) or `localhost`
   - **IMPORTANT**: Do NOT use `sqlLabVM` as the server name - this will cause certificate errors
   - **Authentication**: Windows Authentication
   - Leave other fields as default
   - Check the box for **Trust server certificate**
   - Click **Connect**

5. You should now be connected to SQL Server. In the Object Explorer on the left, you'll see:
   - Your server instance: `(local) (SQL Server 15.0.xxxx - sqlLabVM\cloud_user)`
   - System Databases folder
   - You won't see CarvedRock database yet - you'll create it next

### Objective 1: Diagnose and Optimize Query Performance

In this section, you'll identify performance bottlenecks using Dynamic Management Views (DMVs) and execution plans, then apply optimizations to improve query performance.

**Quick Reference**:
- **Query Windows**: Use Ctrl+N for a new window when instructed
- **Execution Plans**: Use Ctrl+M to enable graphical plans (not SET SHOWPLAN_XML)
- **Results Location**: 
  - Data appears in the **Results** tab
  - Statistics appear in the **Messages** tab
  - Graphical plans appear in the **Execution plan** tab

#### Initial Setup (First Time Only)

**CRITICAL**: You must create the database before starting the performance tuning exercises!

Before starting the exercises, you need to:
1. Download the SQL scripts from GitHub to C:\LabScripts
2. Create the CarvedRock database
3. Run all setup scripts

**Required files to upload to GitHub**:
- `create-database.sql` - Creates database and tables
- `create-performance-issues.sql` - Adds problematic queries  
- `create-blocking-scenario.sql` - Blocking demo procedures
- `maintenance-scripts.sql` - Maintenance procedures (sp_CheckIndexFragmentation, etc.)

1. Check if the lab scripts are available:
   - Open **File Explorer** 
   - Navigate to `C:\LabScripts`
   - You should see SQL files including `create-database.sql`
   
   **If the files are missing**, download them using PowerShell:
   ```powershell
   cd C:\
   mkdir LabScripts
   cd LabScripts
   
   $base = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main"
   Invoke-WebRequest -Uri "$base/create-database.sql" -OutFile "create-database.sql"
   Invoke-WebRequest -Uri "$base/create-performance-issues.sql" -OutFile "create-performance-issues.sql"
   Invoke-WebRequest -Uri "$base/create-blocking-scenario.sql" -OutFile "create-blocking-scenario.sql"
   Invoke-WebRequest -Uri "$base/maintenance-scripts.sql" -OutFile "maintenance-scripts.sql"
   ```

2. In SSMS, **first check if CarvedRock database exists**:
   - Look in Object Explorer under Databases
   - If CarvedRock is not there, you need to create it
   
3. **Create the database** - In a new query window, run:
   ```sql
   -- First, make sure you're in master database
   USE master;
   GO
   ```
   
   Then either:
   - **Option A**: Open and run `C:\LabScripts\create-database.sql`
   - **Option B**: If the file is missing, run this minimal script to create the database:
   ```sql
   -- Check what databases exist
   SELECT name FROM sys.databases;
   
   -- If CarvedRock is not listed, create it:
   USE master;
   GO
   
   CREATE DATABASE CarvedRock;
   GO
   
   USE CarvedRock;
   GO
   
   -- Create the Orders table (minimal version for testing)
   CREATE TABLE Customers (
       CustomerID INT IDENTITY(1,1) PRIMARY KEY,
       FirstName NVARCHAR(50),
       LastName NVARCHAR(50),
       Email NVARCHAR(100)
   );
   
   CREATE TABLE Orders (
       OrderID INT IDENTITY(1,1) PRIMARY KEY,
       CustomerID INT,
       OrderDate DATETIME,
       TotalAmount DECIMAL(10,2)
   );
   
   CREATE TABLE OrderDetails (
       OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
       OrderID INT,
       ProductID INT,
       Quantity INT,
       UnitPrice DECIMAL(10,2)
   );
   
   CREATE TABLE Products (
       ProductID INT IDENTITY(1,1) PRIMARY KEY,
       ProductName NVARCHAR(100)
   );
   
   PRINT 'Basic tables created. Run the full setup scripts for complete data.';
   ```

4. If CarvedRock doesn't exist, run the database creation script:
   - Open `C:\LabScripts\create-database.sql` in SSMS
   - Execute it (F5)
   - This creates the CarvedRock database with all tables
   - Takes about 30-60 seconds to complete

5. After database creation, run the remaining scripts:
   - Open and execute `create-performance-issues.sql`
   - Open and execute `create-blocking-scenario.sql`  
   - Open and execute `maintenance-scripts.sql`

6. Verify the setup:
   - In Object Explorer, right-click **Databases** and select **Refresh**
   - Expand **CarvedRock** > **Tables**
   - You should see: Customers, Orders, OrderDetails, Products tables
   
**Common Error**: "Cannot find the object 'Orders' because it does not exist"
- This means the CarvedRock database or its tables don't exist
- Solution: Run the create-database.sql script first!

#### Troubleshooting Setup Issues

If you're missing the SQL files in `C:\LabScripts`:

1. **The automatic download should have worked** with the PowerShell command above

2. **If SQLCMD mode doesn't work**:
   - Run each SQL file individually in this order:
     1. `create-database.sql`
     2. `create-performance-issues.sql`
     3. `create-blocking-scenario.sql`
     4. `maintenance-scripts.sql`

3. **If scripts fail to run**:
   - Make sure you're connected to `.` or `localhost`
   - Check that SQL Server service is running
   - Try running from PowerShell:
   ```powershell
   sqlcmd -S . -E -i "C:\LabScripts\create-database.sql"
   sqlcmd -S . -E -i "C:\LabScripts\create-performance-issues.sql"
   sqlcmd -S . -E -i "C:\LabScripts\create-blocking-scenario.sql"
   sqlcmd -S . -E -i "C:\LabScripts\maintenance-scripts.sql"
   ```

#### Identifying Performance Issues

**PREREQUISITE CHECK**: Before proceeding, verify the database exists:
```sql
-- Run this first to check
SELECT DB_NAME() AS CurrentDatabase;

-- If it doesn't say 'CarvedRock', run:
USE CarvedRock;
GO

-- If you get an error, go back to Initial Setup section
```

**Important Notes for This Lab**:
- **Query Windows**: Use a new query window (Ctrl+N) for each major task unless specified to use the same window
- **Results**: Check both tabs after running queries:
  - **Results** tab: Shows query output (data)
  - **Messages** tab: Shows execution statistics, row counts, and timing
  - **Execution plan** tab: Shows graphical plan (only when enabled with Ctrl+M)

1. First, identify the slowest queries in the CarvedRock database. In SSMS, open a new query window and run:

    ```sql
    -- Make sure you're in the correct database
    USE CarvedRock;
    GO
    
    SELECT TOP 10
        qs.total_elapsed_time / 1000000.0 AS TotalElapsedTimeSeconds,
        qs.execution_count,
        qs.total_elapsed_time / qs.execution_count / 1000000.0 AS AvgElapsedTimeSeconds,
        SUBSTRING(st.text, (qs.statement_start_offset/2) + 1,
            ((CASE qs.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset
            END - qs.statement_start_offset)/2) + 1) AS QueryText
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE st.text NOT LIKE '%sys.dm_exec_query_stats%'
    ORDER BY qs.total_elapsed_time DESC;
    ```

    **Check the Results tab**: You should see queries with execution times in seconds.

2. Execute a problematic stored procedure and examine its execution plan:

    **In a new query window**, run:

    ```sql
    -- Make sure you're in the correct database
    USE CarvedRock;
    GO
    
    -- Enable statistics
    SET STATISTICS TIME ON;
    SET STATISTICS IO ON;
    
    -- Run the problematic procedure
    EXEC sp_GetCustomerOrderHistory '2024-01-01', '2024-12-31';
    ```

    **Check the Messages tab** for execution time. You should see:
    - Table scan counts
    - Logical reads (high numbers indicate inefficiency)
    - CPU time and elapsed time in milliseconds

3. To view the execution plan:

    **First, turn off any XML plan settings** (in case they're on):
    ```sql
    SET SHOWPLAN_XML OFF;
    GO
    ```

    **Then enable the graphical execution plan**:
    - Press `Ctrl+M` or 
    - Click the **Include Actual Execution Plan** button in the toolbar (looks like a flowchart icon) or
    - Go to Query menu > **Include Actual Execution Plan**
    
    **Now run the query again**:
    ```sql
    EXEC sp_GetCustomerOrderHistory '2024-01-01', '2024-12-31';
    ```

    **View the plan**:
    - After execution, click the **Execution plan** tab (next to Results and Messages)
    - You'll see a graphical flowchart of operations
    
    **If you still see XML text**: You had SET SHOWPLAN_XML ON. The XML contains the same information - look for `<MissingIndexes>` sections which show you need indexes.
    
    **What to look for in the execution plan**:
    - **Missing Index warnings** (green text at the top saying "Missing Index")
    - **Table Scans** or **Clustered Index Scans** (inefficient for large tables)
    - **Thick arrows** between operators (indicates large data movement)
    - **High cost percentages** on specific operators
    
    **From your XML plan**, the missing indexes detected were:
    - Orders table needs index on OrderDate with CustomerID included
    - Orders table needs index on CustomerID with OrderDate
    - OrderDetails table needs index on OrderID with Quantity and UnitPrice included

4. Check for missing indexes using DMVs:

    **Open a new query window** (Ctrl+N) and run:

    ```sql
    SELECT 
        migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS ImprovementMeasure,
        'CREATE INDEX [IX_' + OBJECT_NAME(mid.object_id) + '_' + 
        REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns,''), '[', ''), ']', ''), ', ', '_') + ']' +
        ' ON ' + mid.statement +
        ' (' + ISNULL(mid.equality_columns, '') +
        CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END +
        ISNULL(mid.inequality_columns, '') + ')' +
        ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS CreateIndexStatement
    FROM sys.dm_db_missing_index_groups mig
    INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
    INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
    WHERE mid.database_id = DB_ID()
    ORDER BY ImprovementMeasure DESC;
    ```

    **Check the Results tab**: 
    - You should see CREATE INDEX statements
    - If empty (0 rows), that's OK - the DMVs might not have data yet for a new database
    - The execution plan already showed you which indexes are needed

5. Create the most impactful indexes:

    **IMPORTANT**: First ensure you're in the CarvedRock database:
    ```sql
    USE CarvedRock;
    GO
    ```
    
    **Now create the indexes**:
    ```sql
    CREATE INDEX IX_Orders_CustomerID ON Orders(CustomerID);
    CREATE INDEX IX_Orders_OrderDate ON Orders(OrderDate) INCLUDE (OrderID, TotalAmount);
    CREATE INDEX IX_OrderDetails_OrderID ON OrderDetails(OrderID) INCLUDE (ProductID, Quantity, UnitPrice);
    ```
    
    You should see `Command(s) completed successfully` for each index creation.

6. Re-run the problematic stored procedure to see the improvement:

    **Go back to the query window from step 2** (or open a new one) and run:

    ```sql
    SET STATISTICS TIME ON;
    SET STATISTICS IO ON;
    
    EXEC sp_GetCustomerOrderHistory '2024-01-01', '2024-12-31';
    ```

    **Compare the execution times**:
    - Check the Messages tab
    - The execution time should now be significantly reduced (from seconds to milliseconds)
    - You should see much lower CPU time and elapsed time

7. Also fix the inefficient cursor-based procedure. First, examine the current implementation:

    ```sql
    EXEC sp_helptext 'sp_UpdateInventoryLevels';
    ```

    Note the cursor usage which processes rows one at a time.

8. Create an optimized version using set-based operations:

    ```sql
    CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels_Optimized
    AS
    BEGIN
        -- Set-based update with separate insert (OUTPUT INTO doesn't work with foreign keys)
        BEGIN TRANSACTION;
        
        -- First, identify products that need reordering
        DECLARE @ReorderTable TABLE (
            ProductID INT,
            OldStock INT,
            NewStock INT
        );
        
        -- Update products and capture which ones were updated
        UPDATE Products
        SET StockQuantity = StockQuantity + 100
        OUTPUT 
            INSERTED.ProductID,
            DELETED.StockQuantity AS OldStock,
            INSERTED.StockQuantity AS NewStock
        INTO @ReorderTable
        WHERE StockQuantity < ReorderLevel
            AND Discontinued = 0;
        
        -- Insert transaction records for the updates
        INSERT INTO InventoryTransactions (ProductID, TransactionType, Quantity, Notes)
        SELECT ProductID, 'Reorder', 100, 'Auto-reorder triggered'
        FROM @ReorderTable;
        
        DECLARE @RowCount INT = @@ROWCOUNT;
        
        COMMIT TRANSACTION;
        
        PRINT 'Inventory levels updated using set-based operation.';
        PRINT CAST(@RowCount AS VARCHAR(10)) + ' products reordered.';
    END;
    ```
    
    **Note**: The OUTPUT INTO clause can't directly insert into tables with foreign key relationships, so you use a table variable as an intermediate step.

### Objective 2: Implement and Monitor Automated Administrative Tasks

Now you'll set up SQL Server Agent jobs for automated backups and maintenance, configure alerts, and create a comprehensive maintenance plan.

1. First, ensure SQL Server Agent is running. In SSMS Object Explorer, expand **SQL Server Agent**. If it shows `(Agent XPs disabled)`, right-click and select **Start**.

2. Create a backup job. Right-click **Jobs** under SQL Server Agent and select **New Job**. However, since you're working via commands, execute:

    ```sql
    USE msdb;
    GO
    
    EXEC dbo.sp_add_job
        @job_name = N'CarvedRock Daily Backup',
        @enabled = 1,
        @description = N'Daily full backup of CarvedRock database';
    
    EXEC dbo.sp_add_jobstep
        @job_name = N'CarvedRock Daily Backup',
        @step_name = N'Backup Database',
        @command = N'EXEC CarvedRock.dbo.sp_BackupDatabase;',
        @database_name = N'CarvedRock';
    
    EXEC dbo.sp_add_schedule
        @schedule_name = N'Daily at 2 AM',
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_time = 020000;
    
    EXEC dbo.sp_attach_schedule
        @job_name = N'CarvedRock Daily Backup',
        @schedule_name = N'Daily at 2 AM';
    
    EXEC dbo.sp_add_jobserver
        @job_name = N'CarvedRock Daily Backup';
    ```

    You should see messages confirming each step completed successfully.

3. Create a maintenance job for index optimization and statistics:

    ```sql
    EXEC dbo.sp_add_job
        @job_name = N'CarvedRock Weekly Maintenance',
        @enabled = 1,
        @description = N'Weekly maintenance including index optimization and statistics update';
    
    -- Step 1: Check database integrity
    EXEC dbo.sp_add_jobstep
        @job_name = N'CarvedRock Weekly Maintenance',
        @step_name = N'Check Database Integrity',
        @command = N'DBCC CHECKDB(''CarvedRock'') WITH NO_INFOMSGS;',
        @database_name = N'CarvedRock',
        @on_success_action = 3; -- Go to next step
    
    -- Step 2: Update statistics
    EXEC dbo.sp_add_jobstep
        @job_name = N'CarvedRock Weekly Maintenance',
        @step_name = N'Update Statistics',
        @command = N'EXEC sp_updatestats;',
        @database_name = N'CarvedRock',
        @on_success_action = 3; -- Go to next step
    
    -- Step 3: Maintain indexes
    EXEC dbo.sp_add_jobstep
        @job_name = N'CarvedRock Weekly Maintenance',
        @step_name = N'Maintain Indexes',
        @command = N'EXEC sp_MaintainIndexes;',
        @database_name = N'CarvedRock';
    
    EXEC dbo.sp_add_schedule
        @schedule_name = N'Weekly Sunday at 1 AM',
        @freq_type = 8,
        @freq_interval = 1,
        @freq_recurrence_factor = 1,
        @active_start_time = 010000;
    
    EXEC dbo.sp_attach_schedule
        @job_name = N'CarvedRock Weekly Maintenance',
        @schedule_name = N'Weekly Sunday at 1 AM';
    
    EXEC dbo.sp_add_jobserver
        @job_name = N'CarvedRock Weekly Maintenance';
    ```

4. Configure Database Mail for job notifications (you'll simulate this since email won't actually work in the lab):

    ```sql
    -- Enable Database Mail XPs
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;
    EXEC sp_configure 'Database Mail XPs', 1;
    RECONFIGURE;
    
    -- Note: In a real environment, you would configure mail profiles and accounts
    PRINT 'Database Mail XPs enabled. In production, configure mail profiles for notifications.';
    ```

5. Test the maintenance job by running it manually:

    ```sql
    EXEC msdb.dbo.sp_start_job @job_name = 'CarvedRock Weekly Maintenance';
    ```

    Check the job status:

    ```sql
    SELECT 
        j.name AS JobName,
        run_status,
        CASE run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
        END AS Status,
        run_date,
        run_time,
        run_duration
    FROM msdb.dbo.sysjobhistory h
    INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
    WHERE j.name LIKE 'CarvedRock%'
    ORDER BY run_date DESC, run_time DESC;
    ```

    You should see `Succeeded` status for the job execution.

### Objective 3: Troubleshoot and Resolve Common Database Health Issues

In this section, you'll identify and fix index fragmentation, simulate and resolve blocking scenarios, and perform database integrity checks.

1. First, check the current index fragmentation levels:

    ```sql
    USE CarvedRock;
    GO
    
    EXEC sp_CheckIndexFragmentation;
    ```

    **Expected Results**: 
    - You should see a table showing indexes with fragmentation percentages
    - The procedure will show sample data if no real fragmentation exists
    - Look for indexes marked as needing 'REBUILD' (>30% fragmentation) or 'REORGANIZE' (10-30%)
    
    **Note**: Small lab databases may not show real fragmentation. The procedure provides sample data for learning purposes.

2. Fix fragmented indexes:

    ```sql
    EXEC sp_MaintainIndexes @FragmentationThreshold = 10;
    ```

    Watch the Messages tab. You should see either:
    - Messages about rebuilding/reorganizing specific indexes
    - "No indexes found with fragmentation above 10%"
    - "All indexes are already optimized"
    
    The procedure will tell you exactly what it's doing.

3. Verify fragmentation has been reduced:

    ```sql
    EXEC sp_CheckIndexFragmentation;
    ```

    All indexes should now show low fragmentation percentages (<10%).
    
    **Still empty results?** This is normal if:
    - Your database has small tables (< 1000 pages)
    - The indexes haven't been heavily modified
    - The stored procedure filters out small indexes
    
    The important learning is understanding how to check and fix fragmentation when it occurs in production databases with larger tables.

4. Now, simulate a blocking scenario. Open a **new query window** (Window 1) and run:

    ```sql
    USE CarvedRock;
    GO
    
    EXEC sp_Session1_Blocker;
    ```

    This starts a transaction that will hold locks for 2 minutes.

5. Quickly open **another new query window** (Window 2) and run:

    ```sql
    USE CarvedRock;
    GO
    
    EXEC sp_Session2_Blocked;
    ```

    This query will be blocked and appear to hang.

6. Open a **third query window** (Window 3) to detect the blocking:

    ```sql
    USE CarvedRock;
    GO
    
    EXEC sp_DetectBlocking;
    ```

    You should see:
    - `BlockingSessionID` and `BlockedSessionID`
    - `WaitTimeSeconds` increasing
    - The actual queries causing the blocking

7. To resolve the blocking, you can either wait 2 minutes for the transaction to complete, or force-terminate the blocking session:

    ```sql
    -- Replace XX with the actual BlockingSessionID number from the previous query
    -- For example: EXEC sp_ResolveBlocking @BlockingSessionID = 55;
    EXEC sp_ResolveBlocking @BlockingSessionID = XX;
    ```
    
    **Important**: Replace `XX` with the actual session ID number (like 55, 56, etc.) from the blocking detection query.
    
    After killing the blocking session:
    - Window 2 should complete and show `Session 2: Update completed!`
    - If you get a conversion error, make sure you're using just the number, not 'XX'

8. Perform a database integrity check:

    ```sql
    -- Using the stored procedure (recommended)
    EXEC sp_CheckDatabaseIntegrity;
    ```
    
    You should see:
    ```
    CHECKDB found 0 allocation errors and 0 consistency errors in database 'CarvedRock'.
    Database integrity check completed successfully.
    ```
    
    **Alternative**: If you want to see the full CHECKDB output:
    ```sql
    DBCC CHECKDB('CarvedRock');  -- Without NO_INFOMSGS to see all messages
    ```

9. Finally, run a complete maintenance routine:

    ```sql
    EXEC sp_PerformCompleteMaintenance;
    ```

    This performs all maintenance tasks in sequence: integrity check, statistics update, index maintenance, and backup. You'll see output like:

    ```
    === Starting Complete Database Maintenance ===
    
    1. Checking database integrity...
    Database integrity check completed.
    
    2. Updating statistics...
    Statistics update completed.
    
    3. Maintaining indexes...
    Index maintenance completed.
    
    4. Performing backup...
    Backup completed successfully to: C:\SQLBackups\CarvedRock_2025-07-30 15-30-00.bak
    
    === Maintenance Completed Successfully ===
    ```

## Summary

Congratulations! You've successfully completed all objectives in this lab:

1. **Diagnosed and optimized query performance** by identifying slow queries with DMVs, analyzing execution plans, and creating missing indexes
2. **Implemented automated maintenance** using SQL Server Agent jobs for backups and regular maintenance tasks
3. **Resolved database health issues** including index fragmentation and blocking scenarios

These skills are essential for maintaining healthy, high-performing SQL Server databases in production environments.
