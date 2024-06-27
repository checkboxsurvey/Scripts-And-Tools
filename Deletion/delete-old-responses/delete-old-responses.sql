DECLARE @cutoffDate DATETIME;
DECLARE @DeletedDate DATETIME;
DECLARE @ResponseIDs TABLE (ResponseID BIGINT);

SET @cutoffDate = '2023-01-01'; -- Replace with the desired cutoff date
SET @DeletedDate = GETDATE(); -- Set to the current date

-- Populate @ResponseIDs table with ResponseIDs of responses older than the cutoff date
INSERT INTO @ResponseIDs (ResponseID)
SELECT ResponseID
FROM [dbo].[ckbx_Response]
WHERE (Deleted IS NULL OR Deleted = 0)
  AND LastEdit < @cutoffDate;

-- Update ckbx_Response table
UPDATE ckbx_Response
SET
    Deleted = 1,
    DeletedDate = @DeletedDate
WHERE [ResponseID] IN (SELECT ResponseID FROM @ResponseIDs);

-- Return the number of rows affected by the update
SELECT @@ROWCOUNT;

-- Update ckbx_ResponseAnswers table
UPDATE ckbx_ResponseAnswers
SET Deleted = 1
WHERE [ResponseID] IN (SELECT ResponseID FROM @ResponseIDs);