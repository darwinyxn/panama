/******************************************************************************/
/* Archivo:            pa_caj_tconsal_notd.sp                                 */
/* Motor de Base:      SYBASE                                                 */
/* Base de datos:      cob_atm                                                */
/* Servidor:           HP-ACT                                                 */
/* Aplicacion:         ATM                                                    */
/* Stored procedure:   pa_caj_tconsal_notd                                    */
/* Procesamiento:      OLTP                                                   */
/* Ult.ControlTarea:   J-GPR-5451                                             */
/* Ult.Referencia:     REF 1                                                  */
/* Disenado por:       Danny Quimis                                           */
/* Fecha de escritura: 11/AGO/2025                                            */
/******************************************************************************/
/*                                                                            */
/******************************************************************************/
/* IMPORTANTE                                                                 */
/******************************************************************************/
/*                                                                            */
/* Este  programa  es  parte  de los paquetes  bancarios  propiedad del       */
/* BANCO BOLIVARIANO S.A.                                                     */
/* Su uso no autorizado queda expresamente prohibido así como cualquier       */
/* alteración o agregado hecho por alguno de sus usuarios sin el debido       */
/* consentimiento   por  escrito  de  la   Presidencia  Ejecutiva   del       */
/* BANCO BOLIVARIANO S.A. o su representante.                                 */
/*                                                                            */
/******************************************************************************/
/*                                                                            */
/******************************************************************************/
/* PROPOSITO                                                                  */
/******************************************************************************/
/*                                                                            */
/* Este sp esta deseñado para poder ejecutar el sp "sp_consulta_saldo"  desde */
/* switch postilion para consultar el saldo de clientes sin tarjeta de debito.*/
/*                                                                            */
/******************************************************************************/
/*                                                                            */
/******************************************************************************/
/* MODIFICACIONES                                                             */
/******************************************************************************/
/*  REF   FECHA             AUTOR                        TAREA                */
/*   1   11/AGO/2025    Danny Quimis                Versión inicial           */
/*----------------------------------------------------------------------------*/
/******************************************************************************/

use cob_atm
go

if exists(select 1 from sysobjects where name = 'pa_caj_tconsal_notd' and type = 'P')
begin
   drop procedure dbo.pa_caj_tconsal_notd
   if exists (select 1 from sysobjects where name = 'pa_caj_tconsal_notd' and type = 'P')
     PRINT '<<< DROP PROCEDURE pa_caj_tconsal_notd -- ERROR -- >>>'
    else
     PRINT '== DROP PROCEDURE pa_caj_tconsal_notd *OK* =='
end
go


create procedure dbo.pa_caj_tconsal_notd 
(
    -- definicion de los parametros de entrada
    @e_oficina              int         = 0,            -- Oficina del cajero o de la red (Banred, Medianet,Credimatic)
    @e_trn                  int,                        -- código de la transacción
    @e_cajero               varchar(8)  = null,         -- Código Interno de la Terminal
    @e_atm_secuencial       int,                        -- Secuencial de la terminal
    @e_fecha_trans          datetime,                   -- fecha de la transacción
    @e_fecha_contable       datetime,                   -- fecha contable
    @e_fecha_concilia       datetime    = '01/01/1900', -- fecha de conciliación 
    @e_cod_tarjeta          int         = 0,            -- código interno de la tarjeta
    @e_tarjeta              varchar(19) = null,         -- numero de la tarjeta   
    @e_origen               varchar(5)  = 'BOLIV',      -- Origen de la transaccion dependiendo del canal (BOLIV/VISA/MDNET/BANRE)
    @e_cuenta_debito        varchar(24) = '0000000000', -- número de cuenta a debitar
    @e_cuenta_credito       varchar(24) = '0000000000', -- número de cuenta acreditar
    @e_reentry              char(1)     = 'N',          -- Indicador de reentry 'S' o 'N'
    @e_reverso              char(1)     = 'N',          -- Indicador de reverso 'S', 'N'
    @e_empresa              smallint    = 0,            -- código de empresa
    @e_moneda               varchar(4)  = '840',        -- código ISO de la moneda
    @e_valor                money       = 0,            -- monto de la transacción
    @e_comision             money       = 0,            -- monto de la comisión 
    @e_pais                 varchar(3)  = 'EC',         -- código del país
    @e_solicitud_recibo     char(1)     = 'N',          -- Indicador si el usuario solicito la impresión del recibo
    @e_dispositivo          varchar(2)  = '02',         -- Terminal Type --> 00 Administrative terminal, 01 POS terminal,02 ATM, 03 Home terminal ...
    @e_iso_field22          varchar(3)  = null,         -- valor del campo ISO field22  --> FIELD 22—POS Entry Mode
	@e_iso_field32          varchar(14) = null,         -- valor del campo ISO field32 --> FIELD 32—ACQUIRING INSTITUTION IDENTIFICATION CODE
    @e_iso_field42          varchar(15) = null,         -- valor del campo ISO field42 --> FIELD 42—CARD ACCEPTOR IDENTIFICATION CODE
    @e_iso_field43          varchar(40) = null,         -- valor del campo ISO field43 --> FIELD 43—CARD ACCEPTOR NAME/LOCATION
	@e_codigo_cliente 		int = 0,				    -- Razon de autorizacion standin
    --definicion de los parametros de Salida
    @s_codigo_error         int         = '999999'  out,    -- código de error
    @s_atm_secuencial       int         = 0         out,    -- secuencial
    @s_saldo_disponible     money       = 0         out,    -- Saldo disponible en débito
    @s_saldo_contable       money       = 0         out,    -- Saldo contable en débito
    @s_saldiscr             money       = 0         out,    -- Saldo disponible en crédito
    @s_autorizacion         varchar(6)  = null      out     -- Numero de autorización   
)
as
begin
    --==============================================================
    -- declaracion  de variables  locales
    --============================================================== 
    declare @v_retorno               int,
            @v_ssn                  int,
            @v_sec_host             int,
            @v_aba_banco            int,
            @v_contador_bb          int,
            @v_contador_red         int,
            @v_trn_cob              int,
            @v_id_adquirente        int,
            @v_empresa              smallint,
            @v_rol                  smallint,
            @v_empresa_aut          smallint,
            @v_empresa_trj          smallint,
            @v_fi_banco             smallint,
            @v_ttrn                 smallint,
            @v_moneda               tinyint,
            @v_dispositivo          tinyint,
            @v_fechap               datetime,
            @v_fecha_ult_mov_cta    datetime,
            @v_comision             money,
            @v_tasa_conversion      money,
            @v_log_valor            money,
            @v_salconcr             money,
            @v_offline              char(1),
            @v_aplcobis             char(1),
            @v_ind_exon             char(1),
            @v_veri_tarjeta         char(1),
            @v_gen_autoriza         char(1),
            @v_signo_trn            char(1),
            @v_cobro                char(1),
            @v_notificaSMS          char(1),
            @v_retardo_SMS          char(1),
            @v_ind_comision         char(1),
            @v_veri_cupo            char(1),
            @v_tipo_cupo            char(1),
            @v_canal                char(3),
            @v_fecha_param          char(10),
            @v_codcosto             varchar(4),
            @v_causal_cob           varchar(3),
            @v_term                 varchar(10),
            @v_srv                  varchar(30),
            @v_referencia2          varchar(40),
            @v_referencia4          varchar(40),
            @v_proddeb              varchar(64),
            @v_prodcre              varchar(64),
            @v_rpc                  descripcion,
            @v_referencia5          varchar(40),
            @v_lo_referencia        varchar(40)
    
    if @e_origen = 'BOLIV' 
    begin 
        set @e_oficina = convert(int,right(rtrim(@e_iso_field42),4))
    end
    
    --==============================================================
    -- Inicializacion de variable locales
    --==============================================================
    select  @v_ssn              = 0,
            @v_aba_banco        = 37,
            @v_moneda           = 1,
            @v_dispositivo      = 1,
            @v_codcosto         = '00',
            @v_sec_host         = @e_atm_secuencial,
            @s_atm_secuencial   = @e_atm_secuencial,
            @v_tasa_conversion  = 0,
            @v_rol              = 108,
            @s_codigo_error     = 0,
            @v_retorno           = 0,
            @s_saldo_contable   = 0,
            @s_saldo_disponible = 0,
            @s_saldiscr         = 0,
            @s_autorizacion     = '',
            @e_cuenta_credito   = isnull(@e_cuenta_credito,'0000000000'),
			@v_referencia5      = replicate(' ',8) +isnull(@e_iso_field22,'000') + isnull(@e_iso_field42,''),
            @v_comision         = 0,
            @v_fecha_ult_mov_cta = @e_fecha_trans,
			@v_referencia2		= '',
			@e_comision			= 0
	
    if @e_iso_field32 is not null
    begin 	
		if @e_origen = 'BANRE'
		begin
			select @v_id_adquirente   =  convert(int,right(@e_iso_field32,4))
		end
		else
		begin
			select @v_id_adquirente   =  convert(int,@e_iso_field32)
		end
	end
	
    --==============================================================
    -- Get parametros comunes'
    --==============================================================
    exec @v_retorno = sp_at_ptl_parametros
		-- definicion de los parametros de entrada
		@i_trn          = @e_trn,
		@i_origen       = @e_origen,
		@i_cajero       = @e_cajero,
		@i_empresa      = @e_empresa,
		@i_tarjeta      = @e_tarjeta,
		@i_iso_field32  = @e_iso_field32,
		@i_dispositivo  = @e_dispositivo, 
		-- get fecha de procesos y estado online/offline'
		@o_offline      = @v_offline        out,
		@o_fecha_param  = @v_fecha_param    out,
		@o_fechap       = @v_fechap         out,
		-- get info de la at_ptl_ruteo_tran
		@o_ttrn         = @v_ttrn           out,
		@o_proddeb      = @v_proddeb        out,
		@o_prodcre      = @v_prodcre        out,
		@o_veri_tarjeta = @v_veri_tarjeta   out,
		@o_gen_autoriza = @v_gen_autoriza   out,
		@o_empresa_aut  = @v_empresa_aut    out,
		@o_canal        = @v_canal          out,
		@o_signo_trn    = @v_signo_trn      out,
		@o_ind_comision = @v_ind_comision   out,
		@o_ssn          = @v_ssn            out,
		@o_moneda       = @v_moneda         out,
		@o_fi_banco     = @v_fi_banco       out,
		@o_rol          = @v_rol            out,
		@o_srv          = @v_srv            out,
		@o_aplcobis     = @v_aplcobis       out,
		@o_notificaSMS  = @v_notificaSMS    out,
		@o_retardo_SMS  = @v_retardo_SMS    out,
		@o_codcosto     = @v_codcosto       out,
		@o_dispositivo  = @v_dispositivo    out,
		@o_term         = @v_term           out,
		@o_aba_banco    = @v_aba_banco      out,
		@o_veri_cupo    = @v_veri_cupo      out,
		@o_tipo_cupo    = @v_tipo_cupo      out
    
    if @@error <> 0
	begin
		select @s_codigo_error = @@error
		
		select @v_retorno = @s_codigo_error
		
		insert into cob_atm..at_ruteo (
		rt_cajero, rt_trn, rt_sec_host,
		rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
		rt_fecha_contable, rt_valor, rt_cuenta_debito,
		rt_cuenta_credito, rt_reverso, rt_banco,
		rt_offline, rt_origen, rt_oficina,
		rt_rol, rt_reentry, rt_codigo_error 
		)
		values(
			@e_cajero,          @e_trn,         @e_atm_secuencial,
			@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
			@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
			@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
			@v_offline,         @e_origen,      @e_oficina,
			@v_rol,             @e_reentry,     @s_codigo_error
		)
		
		if @@error<>0  
		begin
			set @v_retorno=160111 
		end
				
		return @v_retorno
	end	
	else if @v_retorno <> 0 
    begin
        select  @s_codigo_error = @v_retorno
		
		insert into cob_atm..at_ruteo (
		rt_cajero, rt_trn, rt_sec_host,
		rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
		rt_fecha_contable, rt_valor, rt_cuenta_debito,
		rt_cuenta_credito, rt_reverso, rt_banco,
		rt_offline, rt_origen, rt_oficina,
		rt_rol, rt_reentry, rt_codigo_error 
		)
		values(
			@e_cajero,          @e_trn,         @e_atm_secuencial,
			@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
			@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
			@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
			@v_offline,         @e_origen,      @e_oficina,
			@v_rol,             @e_reentry,     @s_codigo_error
		)
		
		if @@error<>0  
		begin
			set @v_retorno=160111 
		end
				
		return @v_retorno		
    end
           
    --====================================================================================  
    -- Este segmento de codigo fue colocado al inicio del programa para impedir desde
    -- el inicio la ejecucion de la transaccion si es que los cajeros estan en offline.
    --====================================================================================
    if @v_offline = 'P' or convert(char(10),@e_fecha_concilia,101) != @v_fecha_param
       begin
		select @v_retorno = 160030
		  
		select @s_codigo_error = @v_retorno
		  
		insert into cob_atm..at_ruteo (
		rt_cajero, rt_trn, rt_sec_host,
		rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
		rt_fecha_contable, rt_valor, rt_cuenta_debito,
		rt_cuenta_credito, rt_reverso, rt_banco,
		rt_offline, rt_origen, rt_oficina,
		rt_rol, rt_reentry, rt_codigo_error 
		)
		values(
			@e_cajero,          @e_trn,         @e_atm_secuencial,
			@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
			@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
			@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
			@v_offline,         @e_origen,      @e_oficina,
			@v_rol,             @e_reentry,     @s_codigo_error
		)
			
		if @@error<>0  
		begin
			set @v_retorno=160111 
		end
				
		return @v_retorno
	end
        
    --==============================================================
    -- Validar la logtran
    --==============================================================
    
    if @e_trn not in (16260,16261)
    begin
        exec @v_retorno = sp_at_ptl_valida_logtran
			@i_lo_trn           = @e_trn,
			@i_lo_banco         = @v_aba_banco,
			@i_lo_sec_host      = @e_atm_secuencial,
			@i_lo_codtarjeta    = @e_cod_tarjeta,
			@i_lo_reverso       = @e_reverso,
			@i_lo_valor         = @e_valor,
			@i_cajero           = @e_cajero,
			@i_atm_secuencial   = @e_atm_secuencial,
			@i_cuenta_debito    = @e_cuenta_debito,
			@i_reentry          = @e_reentry ,
			@o_code_return      = @s_codigo_error   out,
			@o_log_valor        = @v_log_valor      out,
			@o_log_comision     = @v_comision       out
        
		if @@error <> 0
		begin
			select @s_codigo_error = @@error
			
			select @v_retorno = @s_codigo_error
			
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
		end
		else if (@v_retorno <> 0 or @s_codigo_error <> 0)
		begin
            select @s_codigo_error = @v_retorno
		  
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
		end
    end
    
    
    --==============================================================
    -- validar Costo/Comision
    --==============================================================
    if @v_ind_comision = 'S'
    begin 
		exec @v_retorno = sp_at_genera_costo_trn 
			@s_ofi           = null,
			@i_causa         = null,
			@s_date          = @v_fechap,
			@t_corr          = @e_reverso,
			@i_moneda        = @v_moneda,
			@i_tarjeta       = @e_tarjeta,
			@i_producto      = @v_proddeb,
			@i_trn           = @e_trn,
			@i_cta           = @e_cuenta_debito,
			@i_contador_bb   = @v_contador_bb,
			@i_contador_red  = @v_contador_red,
			@i_fecha_ult_trn = @v_fecha_ult_mov_cta,
			@i_costo         = @v_comision,
			@i_cod_canal     = @v_canal,
			@i_codcost       = @v_codcosto,
			@o_contador_bb   = @v_contador_bb  out,
			@o_contador_red  = @v_contador_red out,
			@o_retorno       = @v_ind_exon     out,
			@o_costo         = @v_comision     out,
			@o_trn_cob       = @v_trn_cob      out,
			@o_causal_cob    = @v_causal_cob   out
                        
        
        if @@error <> 0
        begin 
			set @v_retorno = @@error
			
			select @s_codigo_error = @v_retorno
		  
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
        end

		if @v_retorno != 0
		begin
			select @s_codigo_error = @v_retorno
		  
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
		end
            
    end
                                                     
    select @v_rpc = case @v_proddeb 
						when 'AHO' then 'sp_consulta_saldo'
						when 'CTE' then 'sp_consulta_saldo'
						when 'PAG' then 'sp_at_consulta_vr'
					end                
 
    set @v_comision = isnull(@v_comision,0)
    --==============================================================
    begin transaction CONSULTASALDO
    --==============================================================
        
        exec @v_retorno = @v_rpc
			@s_ssn          = @v_ssn,               -- secuencial
			@s_srv          = @v_srv,               -- server name
			@s_user         = @e_cajero,            -- w_user
			@s_term         = @v_term,              -- terminal ATMB
			@s_date         = @v_fechap,            -- fecha de  proceso
			@s_ofi          = @e_oficina,           -- w_oficina
			@t_ssn_corr     = @e_atm_secuencial,    -- secuencial  del atm
			@t_rty          = @e_reentry,           -- i_reentry
			@t_trn          = @e_trn,               -- codigo de la trn
			@t_corr         = @e_reverso,           -- indicado de reverso
			@i_aplcobis     = @v_aplcobis,          -- si la aplicacion es cobis
			@i_prodeb       = @v_proddeb,           -- w_proddeb
			@i_cta          = @e_cuenta_debito,     -- @e_cuenta_debito 
			@i_mon          = @v_moneda,            -- @e_moneda
			@i_comision     = @v_comision,          -- w_comision
			@i_trn_cob      = @v_trn_cob,           -- w_trn_cob 
			@i_causal_cob   = @v_causal_cob,        -- w_causal_cob 
			@i_sec_tarjeta  = @e_cod_tarjeta,
			@i_canal        = @v_canal,
			@i_cajero       = @e_cajero,
			@i_empresa_trj  = @v_empresa_trj,
			@i_causa        = '',                   -- no usado **
			@s_lsrv         = null,                 -- no usado **
			@s_sesn         = null,                 -- no usado **
			@s_rol          = null,                 -- no usado **
			@i_tarjeta      = null,                 -- no usado **
			@o_codigo_error = @s_codigo_error       out,
			@o_salcondb     = @s_saldo_contable     out,
			@o_saldisdb     = @s_saldo_disponible   out,
			@o_saldiscr     = @s_saldiscr           out,
			@o_salconcr     = @v_salconcr           out

        if @@error <> 0
		begin
			rollback transaction
			
			select @s_codigo_error = @@error,
					@s_saldo_contable   = 0,
                    @s_saldo_disponible = 0,
                    @s_saldiscr         = 0,
                    @s_autorizacion     = ''
			
			select @v_retorno = @s_codigo_error
			
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
		end
		else if @v_retorno != 0 or @s_codigo_error <> 0
        begin
            rollback transaction
            select  @s_codigo_error     = @v_retorno,
                    @s_saldo_contable   = 0,
                    @s_saldo_disponible = 0,
                    @s_saldiscr         = 0,
                    @s_autorizacion     = ''
            
			select @s_codigo_error = @v_retorno
		  
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
        end

        select @v_cobro = 'N'

        if @v_ind_exon != 'N'
		begin
            select @v_cobro = isnull(@v_ind_exon,'N')
		end
        
        --==============================================================
        -- registra la trn en la logtran'
        --==============================================================
        set @v_empresa = isnull(@e_empresa,0)

        set @v_lo_referencia=null

        exec @v_retorno = sp_at_ptl_logueotran
			@i_lo_atm               = @e_cajero,            
			@i_lo_ttrn              = @v_ttrn,
			@i_lo_trn               = @e_trn,               -- codigo de la trn
			@i_lo_sec_host          = @v_sec_host,
			@i_lo_atm_secuencial    = @e_atm_secuencial,    
			@i_lo_vsecuencial       = @s_atm_secuencial,
			@i_lo_tarjeta           = @e_tarjeta,
			@i_lo_fecha             = @e_fecha_trans,
			@i_lo_valor             = @e_valor,
			@i_lo_cuenta1           = @e_cuenta_debito,
			@i_lo_cuenta2           = @e_cuenta_credito,
			@i_lo_reverso           = @e_reverso,           -- indicado de reverso
			@i_lo_banco             = @v_aba_banco,
			@i_lo_offline           = @v_offline,
			@i_lo_uso_cajero        = @v_cobro,
			@i_lo_oficina           = @e_oficina,
			@i_lo_tasa_conver       = @v_tasa_conversion,
			@i_lo_moneda            = @v_moneda,            -- @e_moneda
			@i_lo_valor_reverso     = @e_valor,
			@i_lo_fecha_concilia    = @e_fecha_contable,
			@i_lo_dispositivo       = @v_dispositivo,
			@i_lo_reentry           = @e_reentry,
			@i_lo_empresa           = @v_empresa,
			@i_lo_referencia        = @v_lo_referencia, 
			@i_lo_referencia2       = @v_referencia2,
			@i_lo_referencia3       = @e_iso_field43,
			@i_lo_referencia4       = @v_referencia4,       
			@i_lo_referencia5       = @v_referencia5,
			@i_lo_pais              = @e_pais,
			@i_lo_comision          = @v_comision,          
			@i_lo_codtarjeta        = @e_cod_tarjeta,
			@i_lo_codcliente        = @e_codigo_cliente,
			@i_lo_valor_isd         = 0,
			@i_lo_autorizacion      = @s_autorizacion,
			@i_lo_solicitud_recibo  = @e_solicitud_recibo,
			@i_id_adquirente        = @v_id_adquirente,
			@o_code_return          = @s_codigo_error out
        
        if @@error <> 0
		begin
			rollback transaction
			
			select @s_codigo_error = @@error,
					@s_saldo_contable   = 0,
                    @s_saldo_disponible = 0,
                    @s_saldiscr         = 0,
                    @s_autorizacion     = ''
					
			select @v_retorno = @s_codigo_error
			
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
		end
        else if @v_retorno <> 0
        begin
            rollback transaction
            set @s_codigo_error = @v_retorno
            
			insert into cob_atm..at_ruteo (
			rt_cajero, rt_trn, rt_sec_host,
			rt_atm_secuencial, rt_tarjeta, rt_fecha_trans,
			rt_fecha_contable, rt_valor, rt_cuenta_debito,
			rt_cuenta_credito, rt_reverso, rt_banco,
			rt_offline, rt_origen, rt_oficina,
			rt_rol, rt_reentry, rt_codigo_error 
			)
			values(
				@e_cajero,          @e_trn,         @e_atm_secuencial,
				@e_atm_secuencial,  @e_tarjeta,     @e_fecha_trans,
				@e_fecha_contable,  @e_valor,       @e_cuenta_debito,
				@e_cuenta_credito,  @e_reverso,     @v_aba_banco,
				@v_offline,         @e_origen,      @e_oficina,
				@v_rol,             @e_reentry,     @s_codigo_error
			)
			
			if @@error<>0  
			begin
				set @v_retorno=160111 
			end
					
			return @v_retorno
        end
    
    --==============================================================
    commit transaction CONSULTASALDO    
    --==============================================================
    
    --====================================================================== 
    -- set valores default a los parametros de salida en caso de ser null
    --======================================================================
    if @s_autorizacion is null
	begin
        set @s_autorizacion = ''
	end

    if @s_atm_secuencial is null
	begin
        set @s_atm_secuencial = 0
	end
    
    if @s_saldo_disponible is null
	begin
        set @s_saldo_disponible = 0
	end

    if @s_saldo_contable is null
	begin
        set @s_saldo_contable = 0
	end

    if @s_saldiscr is null
	begin
        set @s_saldiscr = 0
	end

    set @s_codigo_error = 0
        
    return  @s_codigo_error    
end

go

if exists (select 1 from sysobjects where name = 'pa_caj_tconsal_notd' and type = 'P')
	PRINT '== CREATE PROCEDURE pa_caj_tconsal_notd *OK* =='
else
	PRINT '<<< CREATE PROCEDURE pa_caj_tconsal_notd -- ERROR -- >>>'
go