Use [master];
Set Ansi_Nulls On; Set Quoted_Identifier On;
Go
/*=================================================================================================================\
|                                               INÍCIO DA PROCEDURE                                                |
\=================================================================================================================*/
Go

Create Or Alter Procedure sp_TamanhoTabela
As
  
    Set NoCount On;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    If DB_NAME() <> 'tempdb'
    Begin 

        Declare @Hoje date = getdate() /*dateadd(Day, -1, getdate())*/
              , @UltimaExecucao datetime
              , @Data_Comparacao datetime
              , @Ultima_DataRegistrada date
              , @Flag_UltimoDiaMes char(1) 

        Select @UltimaExecucao = Max(HTT.InsertTime)
          From Backup_Tabelas.dbo.HistoricoTamanhoTabela HTT
         Where HTT.InsertTime < @Hoje
           And HTT.[Database] = DB_NAME()

        If @UltimaExecucao Is null
            Set @UltimaExecucao = convert(date, Dateadd( Day, -1, @Hoje ))

        Set @Flag_UltimoDiaMes = iif( @Hoje = eomonth(@Hoje), 'S', 'N' )

        Set @Data_Comparacao = Case When month(@Hoje) =  1                      Then Dateadd( Month, -1, @Hoje )
                                    When month(@Hoje) =  2                      Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) =  3 And day(@Hoje) <  28 Then Dateadd( Month, -1, @Hoje )
                                    When month(@Hoje) =  3 And day(@Hoje) >= 28 Then eomonth(Dateadd( Month, -1, @Hoje )) 
                                    When month(@Hoje) =  4                      Then eomonth(Dateadd( Month, -1, @Hoje )) 
                                    When month(@Hoje) =  5 And day(@Hoje) < 30 Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) =  5 And day(@Hoje) = 31 Then eomonth(Dateadd( Month, -1, @Hoje )) 
                                    When month(@Hoje) =  6 And day(@Hoje) < 30 Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) =  6 And day(@Hoje) = 31 Then eomonth(Dateadd( Month, -1, @Hoje )) 
                                    When month(@Hoje) =  7 And day(@Hoje) < 30 Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) =  7 And day(@Hoje) = 31 Then eomonth(Dateadd( Month, -1, @Hoje )) 
                                    When month(@Hoje) =  8                     Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) =  9                     Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) = 10 And day(@Hoje) < 30 Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) = 10 And day(@Hoje) = 31 Then eomonth(Dateadd( Month, -1, @Hoje )) 
                                    When month(@Hoje) = 11                     Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) = 12 And day(@Hoje) < 30 Then Dateadd( Month, -1, @Hoje ) 
                                    When month(@Hoje) = 12 And day(@Hoje) = 31 Then eomonth(Dateadd( Month, -1, @Hoje )) 
                                    Else Dateadd( Month, -1, @Hoje )
                                End

        Select (ROW_NUMBER() OVER(ORDER BY t3.name, t2.name))%2 AS l1
        	   ,DB_NAME() Collate SQL_Latin1_General_CP1_CI_AS AS [database]
        	   ,t3.name Collate SQL_Latin1_General_CP1_CI_AS As [schema]
        	   ,t2.name Collate SQL_Latin1_General_CP1_CI_AS As [table]
        	   ,t1.rows AS row_count
        	   ,((t1.reserved + ISNULL(a4.reserved,0))* 8) / 1024 AS reserved_MB 
        	   ,(t1.data * 8) / 1024 AS data_MB
        	   ,((CASE WHEN (t1.used + ISNULL(a4.used,0)) > t1.data THEN (t1.used + ISNULL(a4.used,0)) - t1.data ELSE 0 END) * 8) /1024 AS index_size_MB
        	   ,((CASE WHEN (t1.reserved + ISNULL(a4.reserved,0)) > t1.used THEN (t1.reserved + ISNULL(a4.reserved,0)) - t1.used ELSE 0 END) * 8)/1024 AS unused_MB
               , cast(0 as int) as [DifReserved_MB_MesAnterior] 
               , cast(0 as int) as [DifQtdLinhas_MesAnterior]
               , cast(0 as int) as [DifReserved_MB_DiaAnterior]
               , cast(0 as int) as [DifQtdLinhas_DiaAnterior]
          INTO dbo.#Data
          FROM ( SELECT ps.object_id
        	           ,SUM (CASE WHEN (ps.index_id < 2) 
	    			              THEN row_count 
	    						  ELSE 0 
	    					  END) AS [rows]
        	           ,SUM (ps.reserved_page_count) AS reserved
        	           ,SUM (CASE WHEN (ps.index_id < 2) 
	    			              THEN (ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count) 
	    						  ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count) 
	    					  END) AS data
        	          ,SUM (ps.used_page_count) AS used
                 FROM sys.dm_db_partition_stats ps With (Nolock)
                GROUP BY ps.object_id) AS t1
          LEFT OUTER JOIN ( Select it.parent_id
        	                      ,SUM(ps.reserved_page_count) AS reserved
        	                      ,SUM(ps.used_page_count) AS used
                             From sys.dm_db_partition_stats ps With (Nolock)
                            INNER Join sys.internal_tables it With (Nolock)
	    				       On (it.object_id = ps.object_id) 
                            Where it.internal_type IN (202,204)
                            Group By it.parent_id) AS a4 
            ON (a4.parent_id = t1.object_id)
         INNER JOIN sys.tables t2 With (Nolock)
            ON ( t1.object_id = t2.object_id) 
         INNER JOIN sys.schemas t3 With (Nolock)
            ON (t2.schema_id = t3.schema_id)
         WHERE t2.type <> 'S' 
           AND t2.type <> 'IT'
           And DB_NAME() <> 'tempdb';

        Select HTT.[Database]
             , HTT.[Schema]
             , HTT.[Table]
             , Avg(convert(float,HTT.DifReserved_MB_DiaAnterior)) As MT_DifReserved_MB_DiaAnterior
             , Avg(convert(float,HTT.DifQtdLinhas_DiaAnterior))   As MT_DifQtdLinhas_DiaAnterior
          Into #MediasTrimestrais
          From Backup_Tabelas.dbo.HistoricoTamanhoTabela HTT With (Nolock)
         Where InsertTime > convert(datetime, convert(date, eomonth( @Hoje, -3 )) )
           And HTT.[Database] = DB_NAME()
         Group By HTT.[Database]
                , HTT.[Schema]
                , HTT.[Table]

        Select HTT.[Database]
             , HTT.[Schema]
             , HTT.[Table]
             , Avg(convert(float,HTT.DifReserved_MB_MesAnterior)) As MA_DifReserved_MB_MesAnterior
             , Avg(convert(float,HTT.DifQtdLinhas_MesAnterior))   As MA_DifQtdLinhas_MesAnterior
          Into #MediasAnuais
          From Backup_Tabelas.dbo.HistoricoTamanhoTabela HTT With (NoLock)
         Where InsertTime > convert(datetime, convert(date, eomonth( @Hoje, -12 )) )
           And HTT.Flag_UltimoDiaMes = 'S'
           And HTT.[Database] = DB_NAME()
         Group By HTT.[Database]
                , HTT.[Schema]
                , HTT.[Table]

        INSERT Backup_Tabelas.dbo.HistoricoTamanhoTabela
               (InsertTime, l1, [Database], [Schema], [Table], row_count, reserved_MB, data_MB, index_size_MB, unused_MB
                , DifReserved_MB_MesAnterior, DifQtdLinhas_MesAnterior, DifReserved_MB_DiaAnterior, DifQtdLinhas_DiaAnterior
                , Flag_UltimoDiaMes, Id_Tamanho, Id_Crescimento, Limite_Atingido 
                , MediaCrescimentoAnual_MBMes , MediaCrescimentoTrimestral_MBDia, MediaCrescimentoAnual_LinhaMes, MediaCrescimentoTrimestral_LinhaDia
                , Perc_Crescimento_MB_Mes, Perc_Crescimento_MB_Dia, Perc_Crescimento_Linhas_Mes, Perc_Crescimento_Linhas_Dia )
        SELECT dateadd(Hour, 19, convert(datetime, @Hoje ))
             , D.l1
        	 , DB_NAME() AS [database]
        	 , D.[schema] 
        	 , D.[table]
        	 , D.row_count
        	 , D.reserved_MB
        	 , D.data_MB
        	 , D.index_size_MB
        	 , D.unused_MB
             , D.reserved_MB - isnull(MesAnterior.reserved_MB,0) As DifReserved_MB_MesAnterior /* crescimento bruto */
             , D.row_count - isnull(MesAnterior.row_count,0) As DifQtdLinhas_MesAnterior
             , D.reserved_MB - isnull(DiaAnterior.reserved_MB,0) As DifReserved_MB_DiaAnterior
             , D.row_count - isnull(DiaAnterior.row_count,0) As DifQtdLinhas_DiaAnterior
             , @Flag_UltimoDiaMes
             , Case When D.reserved_MB = 0      Then 0
                    When D.reserved_MB <= 50    Then 1
                    When D.reserved_MB <= 100   Then 2
                    When D.reserved_MB <= 1000  Then 3
                    When D.reserved_MB <= 10000 Then 4
                    When D.reserved_MB <= 50000 Then 5
                    When D.reserved_MB >  50000 Then 6
                    Else 7
                End As Id_Tamanho 

             , Case When D.row_count = 0 And D.reserved_MB = 0 Then 0 --'tabela vazia'
                    When     D.reserved_MB - MesAnterior.reserved_MB = 0
                         and D.row_count - MesAnterior.row_count  = 0
                         and D.reserved_MB - isnull(DiaAnterior.reserved_MB,0)  = 0
                         and D.row_count - isnull(DiaAnterior.row_count,0)  = 0 Then 1 --'sem alteração no tamanho e quantidade de linha'
                    When @Flag_UltimoDiaMes = 'S' 
                         And D.reserved_MB - isnull(MesAnterior.reserved_MB,0) <= 0
                         and D.row_count - isnull(MesAnterior.row_count,0)  <= 0 Then 2 --'redução do tamanho ou linhas'
                    When @Flag_UltimoDiaMes = 'N' 
                         And D.reserved_MB - isnull(DiaAnterior.reserved_MB,0)  <= 0
                         and D.row_count - isnull(DiaAnterior.row_count,0)  <= 0 Then 2 --'redução do tamanho ou linhas'

                    When @Flag_UltimoDiaMes = 'S' And (    D.reserved_MB - isnull(MesAnterior.reserved_MB, 0) > MA.MA_DifReserved_MB_MesAnterior
                                                        and D.row_count - isnull(MesAnterior.row_count, 0) <= MA.MA_DifQtdLinhas_MesAnterior ) 
                                                  Then 4 --'tamanho fora do limite do crescimento mensal'
                    When @Flag_UltimoDiaMes = 'S' And (    D.reserved_MB - isnull(MesAnterior.reserved_MB, 0) <= MA.MA_DifReserved_MB_MesAnterior
                                                        and D.row_count - isnull(MesAnterior.row_count, 0) > MA.MA_DifQtdLinhas_MesAnterior ) 
                                                  Then 5 --'quantidade de linhas fora do limite de crescimento mensal'

                    When @Flag_UltimoDiaMes = 'N' And (    D.reserved_MB - isnull(DiaAnterior.reserved_MB, 0) > MT.MT_DifReserved_MB_DiaAnterior
                                                       and D.row_count - isnull(DiaAnterior.row_count, 0) <= MT.MT_DifQtdLinhas_DiaAnterior ) 
                                                  Then 6 --'tamanho fora do limite do crescimento diário'
                    When @Flag_UltimoDiaMes = 'N' And (    D.reserved_MB - isnull(DiaAnterior.reserved_MB, 0) <= MT.MT_DifReserved_MB_DiaAnterior
                                                       And D.row_count - isnull(DiaAnterior.row_count, 0) > MT.MT_DifQtdLinhas_DiaAnterior ) 
                                                  Then 7 --'quantidade de linhas fora do limite de crescimento diário'
                    Else 3 --'crescimento dentro do normal'

                End As Id_Crescimento
             , Case When D.row_count = 0 And D.reserved_MB = 0 Then 'N'--'tabela vazia'
                    When     D.reserved_MB - isnull(MesAnterior.reserved_MB, 0) = 0
                         and D.row_count - isnull(MesAnterior.row_count, 0)  = 0
                         and D.reserved_MB - isnull(DiaAnterior.reserved_MB, 0)  = 0
                         and D.row_count - isnull(DiaAnterior.row_count, 0)  = 0 Then 'N' --'sem alteração no tamanho e quantidade de linha'
                    When @Flag_UltimoDiaMes = 'S' 
                         And D.reserved_MB - isnull(MesAnterior.reserved_MB, 0) <= 0
                         and D.row_count - isnull(MesAnterior.row_count, 0)  <= 0 Then 'N' --'redução do tamanho ou linhas'
                    When @Flag_UltimoDiaMes = 'N' 
                         And D.reserved_MB - isnull(DiaAnterior.reserved_MB, 0)  <= 0
                         and D.row_count - isnull(DiaAnterior.row_count, 0)  <= 0 Then 'N' --'redução do tamanho ou linhas'


                    When @Flag_UltimoDiaMes = 'S' And (    D.reserved_MB - isnull(MesAnterior.reserved_MB, 0) > MA.MA_DifReserved_MB_MesAnterior
                                                        Or D.row_count - isnull(MesAnterior.row_count, 0) > MA.MA_DifQtdLinhas_MesAnterior ) 
                                                  Then 'S'
                    When @Flag_UltimoDiaMes = 'N' And (    D.reserved_MB - isnull(DiaAnterior.reserved_MB, 0) > MT.MT_DifReserved_MB_DiaAnterior
                                                        Or D.row_count - isnull(DiaAnterior.row_count, 0) > MT.MT_DifQtdLinhas_DiaAnterior ) 
                                                  Then 'S'
                    Else 'N'
                End As Limite_Atingido

            , MediaCrescimentoAnual_MBMes = MA.MA_DifReserved_MB_MesAnterior
            , MediaCrescimentoTrimestral_MBDia = MT.MT_DifReserved_MB_DiaAnterior
            , MediaCrescimentoAnual_LinhaMes = MA.MA_DifQtdLinhas_MesAnterior
            , MediaCrescimentoTrimestral_LinhaDia =MT.MT_DifQtdLinhas_DiaAnterior

            /*  Cresimento em % = ( total periodo atual - total periodo anterior ) / ( total periodo anterior * 100 ) */
            , Perc_Crescimento_MB_Mes     = iif( MesAnterior.reserved_MB = 0, 0.00, ( 1.00 * ( D.reserved_MB - isnull(MesAnterior.reserved_MB, 0) ) ) / ( MesAnterior.reserved_MB * 100.00 ))
            , Perc_Crescimento_MB_Dia     = iif( DiaAnterior.reserved_MB = 0, 0.00, ( 1.00 * ( D.reserved_MB - isnull(DiaAnterior.reserved_MB, 0) ) ) / ( DiaAnterior.reserved_MB * 100.00 ))
            , Perc_Crescimento_Linhas_Mes = iif( MesAnterior.row_count   = 0, 0.00, ( 1.00 * ( D.row_count   - isnull(MesAnterior.row_count, 0) )   ) / ( MesAnterior.row_count * 100.00 )  )
            , Perc_Crescimento_Linhas_Dia = iif( DiaAnterior.row_count   = 0, 0.00, ( 1.00 * ( D.row_count   - isnull(DiaAnterior.row_count, 0) )   ) / ( DiaAnterior.row_count * 100.00 )  )

         FROM dbo.#Data D
         Left Join Backup_Tabelas.dbo.HistoricoTamanhoTabela MesAnterior With (Nolock)
           On MesAnterior.[Database] = D.[database]
          And MesAnterior.[Schema] = D.[schema]
          And MesAnterior.[Table] = D.[table]
          And MesAnterior.InsertTime Between convert(datetime, @Data_Comparacao) And convert(datetime, dateadd(Hour, 23, @Data_Comparacao))
         Left Join Backup_Tabelas.dbo.HistoricoTamanhoTabela DiaAnterior With (Nolock)
           On DiaAnterior.[Database] = D.[database]
          And DiaAnterior.[Schema] = D.[schema]
          And DiaAnterior.[Table] = D.[table]
          And DiaAnterior.InsertTime Between convert(datetime, dateadd(Hour, -1, @UltimaExecucao)) And convert(datetime, dateadd(Hour, 1, @UltimaExecucao))
         Left Join #MediasTrimestrais MT
           On MT.[Database] = D.[database]
          And MT.[Schema] = D.[schema]
          And MT.[Table] = D.[table]
         Left Join #MediasAnuais MA
           On MA.[Database] = D.[database]
          And MA.[Schema] = D.[schema]
          And MA.[Table] = D.[table]
        ORDER BY D.reserved_MB DESC;

    End;

GO


USE MASTER; EXEC sp_ms_marksystemobject 'sp_TamanhoTabela';
GO

/*=================================================================================================================\
|                                              TÉRMINO DA PROCEDURE                                                |
\=================================================================================================================*/


