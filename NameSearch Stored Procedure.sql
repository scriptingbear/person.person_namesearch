USE AdventureWorks2019;

/*
Exercise 1

Create a stored procedure called "NameSearch" that allows users to search 
the Person.Person table for a pattern provided by the user.
The user should be able to search by either first name, last name, or middle name.
You can return all columns from the table; that is to say, feel free to user SELECT *.


The stored procedure should take two arguments:
@NameToSearch: The user will be expected to enter either "first", "middle", or "last". 
This way, they do not have to remember exact column names.

@SearchPattern: The user will provide a text string to search for.
A record should be returned if the specified name (first, middle, or last) includes 
the specified pattern anywhere within it. I.e., if the user tells us to search the 
FirstName field for the pattern "ravi", both the names "Ravi" and "Travis" should be returned.

Exercise 2

Modify your "NameSearch" procedure to accept a third argument - 
@MatchType, with an INT datatype -  that specifies the match type:

1 means "exact match"
2 means "begins with"
3 means "ends with"
4 means "contains"

Hint: Use a series of IF statements to build out your WHERE clause based on the 
@MatchType parameter, then append this to the rest of your dynamic SQL before executing.

*/

-- Drop the stored procedure (SP) if it already exists
DECLARE @ProcName VARCHAR(50) = 'NameSearch'
IF OBJECT_ID(@ProcName,'P') IS NOT NULL
	EXECUTE('DROP PROCEDURE ' + @ProcName)

GO
CREATE PROCEDURE dbo.NameSearch
(@NameToSearch NVARCHAR(6), 
@SearchPattern NVARCHAR(100),
@MatchType TINYINT)

AS

BEGIN
	-- Validate inputs
	IF @NameToSearch IS NULL OR @SearchPattern IS NULL OR @MatchType IS NULL
		BEGIN
			PRINT 'Missing NameToSearch, SearchPattern, or MatchType value'
			RETURN 1
		END

	IF LOWER(@NameToSearch) NOT IN ('first','middle','last')
		BEGIN
			PRINT 'Invalid NameToSearch value: ''' + @NameToSearch + ''''
			RETURN 1
		END

	IF TRIM(@SearchPattern) = ''
		BEGIN
			PRINT 'Blank SearchPattern'
			RETURN 1
		END

	IF NOT @MatchType IN (1,2,3,4)
		BEGIN
			PRINT 'Invalid MatchType value'
			RETURN 1
		END

	-- Create a variable to hold the dynamically generated SQL statement
	DECLARE @SQL NVARCHAR(1000)
	-- Create a TVP that maps user column name input to actual table column name
	DECLARE @ColMap TABLE (UserInput VARCHAR(6), TableColumn VARCHAR(20))
	-- Populate TVP with column name mappings
	INSERT INTO @ColMap 
	(UserInput, TableColumn)
	VALUES
	('first', 'FirstName'),
	('middle', 'MiddleName'),
	('last', 'LastName')

	-- Create a variable to hold the name of the column that will be searched
	DECLARE @SearchColumn NVARCHAR(10)
	SELECT @SearchColumn = 
		(SELECT TableColumn FROM @ColMap WHERE UserInput = LOWER(@NameToSearch))


	-- Create a TVP containing 2 columns: selected matching type and dynamically composed
	-- pattern.
	DECLARE @SearchPatternTable TABLE (MatchType TINYINT, Pattern VARCHAR(100))
	INSERT INTO @SearchPatternTable 
	(MatchType, Pattern) 
	VALUES
	(1,@SearchPattern),
	(2,@SearchPattern + '%'),
	(3,'%' + @SearchPattern),
	(4,'%' + @SearchPattern + '%')

	SET @SearchPattern = (SELECT Pattern FROM @SearchPatternTable WHERE MatchType = @MatchType)

	-- Construct parameterized dynamic SQL statement. Note that you cannot use
	-- column names as parameters. The query always returns 0 rows when a parameter
	-- representing a column, e.g. FirstName, is used.
	SET @SQL = N'SELECT * FROM Person.Person WHERE ' + @SearchColumn + ' LIKE @PatternParam'

	/* Use a try/catch block to validate dynamic SQL statement and exit early
	   if it fails. This will not trap all types of errors, however.
	   Use Execute sp_executesql with parameters. Pattern is
	   EXECUTE sp_executesql @SQL, @ParamDefs, @Param1 = value1, @Param2 = value2, ...
	*/
	-- Create variable to hold the dynamic SQL statement parameters and their data types
	DECLARE @ParamDefs NVARCHAR(1000) = N'@PatternParam NVARCHAR(100)'

	BEGIN TRY
		EXECUTE sp_executesql @SQL, @ParamDefs, @PatternParam = @SearchPattern
	END TRY

	BEGIN CATCH
		-- Create a variable to hold the error message
		DECLARE @ErrorMsg VARCHAR(MAX)
		SET @ErrorMsg = 'An error has occured in stored procedure '
		SET @ErrorMsg += ERROR_PROCEDURE() + ' at line '
		SET @ErrorMsg += CAST(ERROR_LINE() AS VARCHAR(5)) 
		SET @ErrorMsg += CHAR(13) 
		SET @ErrorMsg += ERROR_MESSAGE()
		PRINT @ErrorMsg
		RETURN 1
	END CATCH

	PRINT 'Results for Search Column [' + @SearchColumn + '] and Search Pattern ''' 
		+ @SearchPattern + ''''
	RETURN 0

END

--Test exact matching
EXECUTE NameSearch 'last', 'Davis', 1
--(77 rows affected)
--Results for Search Column [LastName] and Search Pattern 'Davis'

--Test begins with matching
EXECUTE NameSearch 'fIrSt', 'Al', 2
--(728 rows affected)
--Results for Search Column [FirstName] and Search Pattern 'Al%'

--Test ends with matching
EXECUTE NameSearch 'fIrSt', 'ck', 3
--(150 rows affected)
--Results for Search Column [FirstName] and Search Pattern '%ck'

--Test contains matching
EXECUTE NameSearch 'MiDdlE', 'm', 4
--(1228 rows affected)
--Results for Search Column [MiddleName] and Search Pattern '%m%'

--Test invalid inputs
EXECUTE NameSearch 'sql', 'ABC', 1
--Invalid NameToSearch value: 'sql'

EXECUTE NameSearch 'last', '' , 2
--Blank SearchPattern

EXECUTE NameSearch 'FIRST', 'JACk' , 8
--Invalid MatchType value