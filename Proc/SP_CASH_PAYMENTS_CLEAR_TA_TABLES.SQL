
/********************************************************************************************************/
/* ��������� �� ���������� ��������� �� TA ��������� */
/* 2022/06/98 - v2.6.3 -> �������������� �� �������� � ����������� ��������� �� �������� ���� �� ������ ������� ������ */
DROP PROCEDURE IF EXISTS dbo.[SP_CASH_PAYMENTS_CLEAR_TA_TABLES]
GO

CREATE PROCEDURE dbo.[SP_CASH_PAYMENTS_CLEAR_TA_TABLES]
(
	@TestCaseRowID NVARCHAR(16)
)
as 
begin

	declare @LogTraceInfo int = 1,	@LogBegEndProc int = 1,	@TimeBeg datetime = GetDate();
	;

	declare @Msg nvarchar(max) = N'', @Rows int = 0, @Err int = 0
		,	@Sql1 nvarchar(4000) = N'',	@TA_RowID int = cast ( @TestCaseRowID as int )
	;
	/************************************************************************************************************/
	/* 1. Log Begining of Procedure execution */
	if @LogBegEndProc = 1 exec dbo.SP_SYS_LOG_PROC @@PROCID, @TestCaseRowID, '*** Begin Execute Proc ***: dbo.[SP_CASH_PAYMENTS_CLEAR_TA_TABLES]'


	/************************************************************************************************************/
	-- 2. Get  TA Table Row IDs:
	declare @RUNNING_ORDER			int = 0
		,	@TYPE_ACTION			varchar(128) = ''
		,	@RAZPREG_TA_RowID		int = 0
		,	@DEALS_CORR_TA_RowID	int = 0
		,	@DT015_CUSTOMERS_RowID	int = 0
		,	@PROXY_CUSTOMERS_RowID	int = 0
		,	@CUSTOMER_BEN_ROW_ID	int = 0		
		,	@RAZPREG_TA_BEN_RowID	int = 0
	;
	select	@RAZPREG_TA_RowID		= [DEAL_ROW_ID]
		,	@DEALS_CORR_TA_RowID	= [CORS_ROW_ID]
		,	@DT015_CUSTOMERS_RowID	= [CUST_ROW_ID]
		,	@PROXY_CUSTOMERS_RowID	= [PROXY_ROW_ID]
		,	@PROXY_CUSTOMERS_RowID	= [PROXY_ROW_ID]
		,	@RUNNING_ORDER			= [RUNNING_ORDER]
		,	@CUSTOMER_BEN_ROW_ID	= IsNull([CUST_BEN_ROW_ID],-1)		
		,	@RAZPREG_TA_BEN_RowID	= IsNull( [DEAL_BEN_ROW_ID],-1)
	from dbo.[VIEW_CASH_PAYMENTS_CONDITIONS] with(nolock)
	where [ROW_ID] = @TA_RowID
	;

	declare @IsNotFirstCashPaymentWithAccumulatedTax bit = 0
	;
	if IsNull(@TYPE_ACTION,'') = 'CashPayment' and IsNull(@RUNNING_ORDER,-1) > 1
		select @IsNotFirstCashPaymentWithAccumulatedTax = 1;

	if IsNull(@RAZPREG_TA_RowID,0) <= 0
	begin  
		select @Msg = 'Not found deal from TA ROW_ID : ' + @TestCaseRowID;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @TestCaseRowID, @Msg
		return 1;
	end
	
	if IsNull(@DT015_CUSTOMERS_RowID,0) <= 0
	begin  
		select @Msg = 'Not found customer from TA ROW_ID : ' + @TestCaseRowID;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @TestCaseRowID, @Msg
		return 2;
	end 

	begin try

		-- ������������ ������� �� ���������������� ������
		if IsNull(@DEALS_CORR_TA_RowID,0) > 0 and @IsNotFirstCashPaymentWithAccumulatedTax = 0
		begin
			update [D]
			set		[DEAL_NUM]				= 0		-- DEALS_CORR_TA	DEAL_NUM	����� �� �������������� ������
				,	[UI_CORR_ACCOUNT]		= ''	-- DEALS_CORR_TA	UI_CORR_ACCOUNT	������� �� ���������������� ������
				,	[TAX_UNCOLLECTED_SUM]	= 0		-- DEALS_CORR_TA	TAX_UNCOLLECTED_SUM	 /* @TODO: ������ �� � �������� !!!... */ 
			from dbo.[DEALS_CORR_TA] [D]
			where [D].[ROW_ID] = @DEALS_CORR_TA_RowID
		end

		-- ������������ ������� �� ������������
		if IsNull(@PROXY_CUSTOMERS_RowID,0) > 0 and @IsNotFirstCashPaymentWithAccumulatedTax = 0
		begin
			update [D]
			set		[UI_CUSTOMER_ID]		= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_CUSTOMER_ID
				,	[UI_EGFN]				= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_EGFN
				,	[NAME]					= ''		-- DT015_CUSTOMERS_ACTIONS_TA	NAME
				,	[COMPANY_EFN]			= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	COMPANY_EFN
				,	[UI_CLIENT_CODE]		= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_CLIENT_CODE
				,	[UI_NOTES_EXIST]		= 0			-- DT015_CUSTOMERS_ACTIONS_TA	UI_NOTES_EXIST
				,	[IS_ZAPOR]				= 0			-- DT015_CUSTOMERS_ACTIONS_TA	IS_ZAPOR (���� ��� ������� ����� ����� �� �������� �� �������) 	�� �� ��������� ���������� � ���������
				,	[ID_NUMBER]				= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	ID_NUMBER ����� �� ����� �����
				,	[SERVICE_GROUP_EGFN]	= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	SERVICE_GROUP_EGFN	EGFN, ����� �� ������� � ������������� ������ �� ������� ������ IS_SERVICE
				,	[IS_ACTUAL]				= 0			-- DT015_CUSTOMERS_ACTIONS_TA	IS_ACTUAL (1; 0)	�� �� ��������� ���������� � ��������� �� ������� � ���������� ����� ��� 1
				,	[PROXY_COUNT]			= 0			-- DT015_CUSTOMERS_ACTIONS_TA	PROXY_COUNT	���� ������� ������������
			from dbo.[DT015_CUSTOMERS_ACTIONS_TA] [D]
			where [D].[ROW_ID] = @PROXY_CUSTOMERS_RowID
		end

		-- ������������ ������� �� ��������
		if @IsNotFirstCashPaymentWithAccumulatedTax = 0
		begin
			update [D]
			set		[UI_DEAL_NUM]			= 0		-- RAZPREG_TA	UI_DEAL_NUM	
				,	[DB_ACCOUNT]			= ''	-- RAZPREG_TA	DB_ACCOUNT	
				,	[UI_ACCOUNT]			= ''	/* TODO: new function + date in TA TABLE */ -- RAZPREG_TA	UI_ACCOUNT 
				,	[ZAPOR_SUM]				= ''	-- RAZPREG_TA	ZAPOR_SUM	���� �� ����� �� �������� (�� ������ �� �������� �� �����)
				,	[IBAN]					= ''	-- RAZPREG_TA	IBAN	
				,	[TAX_UNCOLLECTED_SUM]	= ''	-- RAZPREG_TA	TAX_UNCOLLECTED_SUM	���� �� ����������� �����. ��� ���� �� �� ������� 0.00
			from dbo.[RAZPREG_TA] [D]
			where [D].[ROW_ID] in ( @RAZPREG_TA_RowID, @RAZPREG_TA_BEN_RowID )
		end

		-- ������������ ������� �� �������
		if @IsNotFirstCashPaymentWithAccumulatedTax = 0
		begin		
			update [D]
			set		[UI_CUSTOMER_ID]		= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_CUSTOMER_ID
				,	[UI_EGFN]				= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_EGFN
				,	[NAME]					= ''		-- DT015_CUSTOMERS_ACTIONS_TA	NAME
				,	[COMPANY_EFN]			= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	COMPANY_EFN
				,	[UI_CLIENT_CODE]		= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_CLIENT_CODE
				,	[UI_NOTES_EXIST]		= 0			-- DT015_CUSTOMERS_ACTIONS_TA	UI_NOTES_EXIST
				,	[IS_ZAPOR]				= 0			-- DT015_CUSTOMERS_ACTIONS_TA	IS_ZAPOR (���� ��� ������� ����� ����� �� �������� �� �������) 	�� �� ��������� ���������� � ���������
				,	[ID_TYPE]				= 0
				,	[ID_NUMBER]				= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	ID_NUMBER ����� �� ����� �����
				,	[SERVICE_GROUP_EGFN]	= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	SERVICE_GROUP_EGFN	EGFN, ����� �� ������� � ������������� ������ �� ������� ������ IS_SERVICE
				,	[IS_ACTUAL]				= 0			-- DT015_CUSTOMERS_ACTIONS_TA	IS_ACTUAL (1; 0)	�� �� ��������� ���������� � ��������� �� ������� � ���������� ����� ��� 1
				,	[PROXY_COUNT]			= 0			-- DT015_CUSTOMERS_ACTIONS_TA	PROXY_COUNT	���� ������� ������������
			from dbo.[DT015_CUSTOMERS_ACTIONS_TA] [D]
			where [D].[ROW_ID] = @DT015_CUSTOMERS_RowID
		end

		-- ������������ ������� �� ��������� ( �� ���� ���� ��� �� ����� � ����������� )
		if @IsNotFirstCashPaymentWithAccumulatedTax = 0
		begin
			update [D]
			set 	[TAX_CODE]	= 0		/* ��� �� ����� */
				,	[PREF_CODE]	= 0		/* ��� �� ����������� */
			from dbo.[PREV_COMMON_TA] [D]
			where [D].[ROW_ID] = @TA_RowID
		end

		-- ���������� ������� �� ����������� 
		if IsNull(@CUSTOMER_BEN_ROW_ID,0) > 0 and @IsNotFirstCashPaymentWithAccumulatedTax = 0
		begin		
			update [D]
			set		[UI_CUSTOMER_ID]		= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_CUSTOMER_ID
				,	[UI_EGFN]				= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_EGFN
				,	[NAME]					= ''		-- DT015_CUSTOMERS_ACTIONS_TA	NAME
				,	[COMPANY_EFN]			= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	COMPANY_EFN
				,	[UI_CLIENT_CODE]		= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	UI_CLIENT_CODE
				,	[UI_NOTES_EXIST]		= 0			-- DT015_CUSTOMERS_ACTIONS_TA	UI_NOTES_EXIST
				,	[IS_ZAPOR]				= 0			-- DT015_CUSTOMERS_ACTIONS_TA	IS_ZAPOR (���� ��� ������� ����� ����� �� �������� �� �������) 	�� �� ��������� ���������� � ���������
				,	[ID_TYPE]				= 0
				,	[ID_NUMBER]				= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	ID_NUMBER ����� �� ����� �����
				,	[SERVICE_GROUP_EGFN]	= '0'		-- DT015_CUSTOMERS_ACTIONS_TA	SERVICE_GROUP_EGFN	EGFN, ����� �� ������� � ������������� ������ �� ������� ������ IS_SERVICE
				,	[IS_ACTUAL]				= 0			-- DT015_CUSTOMERS_ACTIONS_TA	IS_ACTUAL (1; 0)	�� �� ��������� ���������� � ��������� �� ������� � ���������� ����� ��� 1
				,	[PROXY_COUNT]			= 0			-- DT015_CUSTOMERS_ACTIONS_TA	PROXY_COUNT	���� ������� ������������
			from dbo.[DT015_CUSTOMERS_ACTIONS_TA] [D]
			where [D].[ROW_ID] = @CUSTOMER_BEN_ROW_ID
		end

	end try
	begin catch
		select  @Msg = dbo.FN_GET_EXCEPTION_INFO()
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
		return 3
	end catch 

	/************************************************************************************************************/
	/* Log End Of Procedure */
	if @LogBegEndProc = 1
	begin 
		select @Msg = 'Duration: '+ dbo.FN_GET_TIME_DIFF(@TimeBeg, GetDate()) + 
			 + ', TA Row ID: ' + @TestCaseRowID
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Msg, '*** End Execute Proc ***: dbo.dbo.[SP_CASH_PAYMENTS_CLEAR_TA_TABLES]'
	end

	return 0;
end 
go
