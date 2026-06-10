Use master
Go

/*=================================================================================================================\
|                                               INÍCIO DA PROCEDURE                                                |
\=================================================================================================================*/
Create Or Alter Procedure STP_CheckList_MonitorarCrescimentoDosDados
As
    Begin

            Declare @Ultima_DataRegistrada date
                  , @Ultimo_DiaMesPassado datetime
    
                Set @Ultimo_DiaMesPassado = eomonth(dateadd(Month, -1, getdate()))

            /* Obter ultima execução */
            Select @Ultima_DataRegistrada = Max(HTT.InsertTime)
              From Backup_Tabelas.dbo.HistoricoTamanhoTabela HTT

            /* Validar se virou o mês */
            If month(@Ultima_DataRegistrada) <> month(getdate())
            Begin
                /* Marcar a última execução como o último dia do mês */
                Update HTT
                   Set Flag_UltimoDiaMes = 'S'
                  From Backup_Tabelas.dbo.HistoricoTamanhoTabela HTT
                 Where HTT.InsertTime Between convert(datetime, @Ultimo_DiaMesPassado) And convert(datetime, dateadd(Hour, 23, @Ultimo_DiaMesPassado)) 

                /* Excluir os dias que não são o ultimo dia à mais de 3 meses */
                Delete Backup_Tabelas.dbo.HistoricoTamanhoTabela 
                 Where convert(date, InsertTime) <= eomonth( getdate(), -4 )
                   And Flag_UltimoDiaMes = 'N'

                /* Excluir os registros mais velhos que 5 anos */
                Delete Backup_Tabelas.dbo.HistoricoTamanhoTabela 
                 Where InsertTime <= EOMonth( GetDate(), -61 )
                 
            End

        /* Obter novos dados */
        Exec master..sp_MSforeachDB  'use [?] exec sp_TamanhoTabela; '

        /*Gerar tabela com as tabelas e médias*/

        -- ao monitorar, o que estiver fora, precisará se corrigido, ou anotado o motivo na própria linha ou em uma tabela de excessões


    End
Go