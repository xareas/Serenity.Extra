ALTER PROCEDURE [dbo].[ReplaceRow]
	@refTableName varchar(255),
	@refColName varchar(255),
	@refValue int,
	@refNewValue int
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @sql nvarchar (255);
	
	BEGIN TRANSACTION
		
	-- Create Cursor for related tables query.
	DECLARE RelatedTableCursor CURSOR 
		LOCAL STATIC READ_ONLY FORWARD_ONLY
	FOR
	SELECT
		result.TableSchemaName +'.'+ result.TableName,
		result.ColumnName
	FROM
	(
		SELECT
			SCHEMA_NAME(a.SCHEMA_ID) TableSchemaName,
			OBJECT_NAME(f.parent_object_id) AS TableName,
			COL_NAME(fc.parent_object_id,fc.parent_column_id) AS ColumnName,
			SCHEMA_NAME(o.SCHEMA_ID) ReferenceSchemaName,
			OBJECT_NAME (f.referenced_object_id) AS ReferenceTableName,
			COL_NAME(fc.referenced_object_id,fc.referenced_column_id) AS ReferenceColumnName
		FROM sys.foreign_keys AS f
		INNER JOIN sys.foreign_key_columns AS fc ON f.OBJECT_ID = fc.constraint_object_id
		INNER JOIN sys.objects AS a ON a.OBJECT_ID = f.parent_object_id
		INNER JOIN sys.objects AS o ON o.OBJECT_ID = fc.referenced_object_id
	) result
	WHERE
		ReferenceSchemaName + '.' + ReferenceTableName = @refTableName AND ReferenceColumnName = @refColName
		
	-- Loop all related tables
	OPEN RelatedTableCursor
	WHILE 1 = 1
	BEGIN 
		DECLARE @tableName varchar(255)
		DECLARE @columnName varchar(255)

		FETCH NEXT FROM RelatedTableCursor into @tableName, @columnName
	
		IF @@fetch_status <> 0
		BEGIN
			BREAK
		END
	
		SET @sql = 
			N'UPDATE ' + @tableName + ' ' +
			' SET ' +
			'	[' + @columnName + '] = ''' + CONVERT(NVARCHAR(255), @refNewValue) + '''' +
			' WHERE [' + @columnName + '] = ''' + CONVERT(NVARCHAR(255), @refValue) + '''';
		
		BEGIN TRY
			EXEC sp_executesql @sql;
		END TRY
		BEGIN CATCH
		END CATCH
	END
	CLOSE RelatedTableCursor
	DEALLOCATE RelatedTableCursor
	
	-- Delete row from primary table
	SET @sql = 'DELETE FROM ' + @refTableName + ' WHERE ' + @refColName + ' = ''' + CONVERT(NVARCHAR(255), @refValue) + '''';
	EXEC sp_executesql @sql;

	COMMIT

END