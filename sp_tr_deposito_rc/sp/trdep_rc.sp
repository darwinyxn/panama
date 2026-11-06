/************************************************************************/
/*    Archivo:                trdep_rc.sp                               */
/*    Motor de Base:          SYBASE                                    */
/*    Stored procedure:       sp_tr_deposito_rc                         */
/*    Base de datos:          cob_cuentas                               */
/*    Servidor:               HP-ACT                                    */
/*    Aplicacion:             Recaudaciones                             */
/*    Producto:               CUENTAS CORRIENTES                        */
/*    Disenado por:           Mauricio Bayas/Sandra Ortiz               */
/*    Fecha de escritura:     16-Dic-1992                               */
/*    Procesamiento:          OLTP                                      */
/* 	  Ult.ControlTarea:       GPR-19111			        */
/* 	  Ult.Referencia:         REF 54                                */
/************************************************************************/
/*              IMPORTANTE                                              */
/*  Este programa es parte de los paquetes bancarios propiedad de       */
/*  'BANCO BOLIVARIANO'.                                                */
/*  Su uso no autorizado queda expresamente prohibido asi como          */
/*  cualquier alteracion o agregado hecho por alguno de sus             */
/*  usuarios sin el debido consentimiento por escrito de la             */
/*  Presidencia Ejecutiva de BANCO BOLIVARIANO o su representante.      */
/************************************************************************/
/*              PROPOSITO                                               */
/*  Este programa procesa la transaccion de deposito completo           */
/************************************************************************/
/*              MODIFICACIONES                                          */
/*    FECHA       AUTOR         RAZON                                   */
/*  16/Nov/1992  J Navarrete    Emision inicial                         */
/*  12/10/1998   L/Granda       calculo del impuesto 1%                 */
/*  11/Nov/1999  C.Montesdeoca  Cambiar mensaje - solicitar autorizacion*/
/*  29/Abr/2000  R. Egas        Dolarizacion                            */
/*  03/May/2000  R. Egas        Cupos de autorizacion                   */
/*  05/May/2000  R. Egas        Cupos de aut. No validar tipo cta       */
/*  19/May/2000  R. Egas        Validar montos minimos                  */
/*  06/Oct/2000  J. Mora        Llamada a buzon por cupo de deposito    */
/*  27/Nov/2000  R. Egas        cambios para funcionamiento en L2       */
/*  22/Mar/2001  Galo Yanez Visualizar mensajes de error                */
/*  27/Jun/2001  R. Castillo    Bloquear el control de montos maximos   */
/*              y minimos.                                              */
/*  14/Sep/2001  R. Castillo    Ingresar el c�digo del Deposito para    */
/*              las cuentas de Dicensa en el campo                      */
/*              tm_beneficiario, el Mismo que se lo                     */
/*              Utilizara para estos casos.                             */
/*  15/Oct/2001  Galo Yanez Validar que ingrse referencia si cuenta     */
/*              pertenece a catalogo                                    */
/*  25/oct/2001  Rosa Castillo  Depositos Especiales x Recaudaciones de */
/*              servicios se adiciona las siguintes trn:                */
/*      3288        DEPOSITO ESTPECIAL                                  */
/*      3289        DEPOSITO ESPECIAL DIFERIDO                          */
/*              . Grabar la Causa de la transaccion                     */
/*              . El codigo del deposito = Codigo del                   */
/*                Cliente                                               */
/*              . Generar Totales de caja por Causa                     */
/*              . Control de Lotes por tipo de Trn.                     */
/*  11/Dic/2001 R. Castillo Cambiar la Longitud del c�digo              */
/*  30/May/2002 M.Sanchez D.    Validacion Ctas en catalogo de Valida_  */
/*                              dacion de Codigos                       */
/*  05/Jun/2002 M.Sanchez D.    Revision de Codigos de origen de Cta en */
/*                              tabla de cob_cuentas..cc_origen_codigo  */
/*  13/Jun/2002 W.Ramirez B.    Control de Depositos Especiales         */
/*  26/Jun/2002 R. Castillo . Migracion Contable                        */
/*  09/Ago/2002 E.Sanchez B.    No permitir dep. de ctas rot. egreso    */
/*  19/Ago/2002 E.Sanchez B.    Cambio tabla para validar codigo en dep */
/*                            cc_origen_codigo por catalogo cc_sublineas*/
/*  26/Ago/2002 R.Castillo      Permitir Realizar Depositos a Ctas del  */
/*              Sector Publico. de Ingreso                              */
/*  17/Ene/2003 F. Moncayo V.   Optimizaci�n por Contencion             */
/*              V. Mu�oz, GGonzalez                                     */
/*  05/Feb/2003 S. Medina.      Parametros en Deposito especial         */
/*  02/May/2003 SIPECOM. Reingenieria de Caja                           */
/*  21/Jul/2003     CVJ     Control de las actualizaciones a            */
/*                      tab. cc_cons_automatica_rc en el                */
/*                  campo ca_status en caso de                          */
/*                  existir error en los SP de vali-                    */
/*                  cion                                                */
/*  31/Oct/2003                                                         */
/*  26/Feb/2004 Julio Velez   pasar parametros que necesita             */
/*                            sp_verificacion_deposito_rc               */
/* EAS1 19May04     E.Avila S.         Valida Dep.Inicial para cuentas  */
/*                                     aperturadas por solicitud        */
/*  14/Jul/2004 F. Moncayo V.   Ampliacion de Digitos de Empresas       */
/*  30/Sep/2005 J.Pazmnno       Considerar fuera de horario para trx en */
/*                              offline (reentry)                       */
/*16Agosto2006 Mauricio Echeverr�a Validaci�n de ctas de deposito       */
/*           cial               					*/
/*17 16/Mayo/2011 Tania Cumbicus  ATMFULL-286-CU-1676 incluir a canal	*/ 
/*				  ATM para depositos			*/
/*18 13/Oct/2011 smerino  CTE-CC-10700 Validac=n de moneda Euros en 	*/
/*					canal ATM 			*/
/*    19 12/Dic/2011  Galo Yanez  Cambio de catalogo a tabla  		*/
/*          para codigos de afectaciones  				*/
/*          Tarea: CTE-CC-10883   					*/
/*    20 22/Feb/2012  Galo Yanez  Realizar convert a campo  		*/
/*          de tabla a varchar en vista 				*/
/*          que en depositos especiales 				*/
/*          hay codigos alfanumericos 					*/
/*          Tarea: CTE-8921     					*/
/*   30/May/2012  Galo Yanez  Actualizar fecha de apertura para cuentas	*/
/*        en estado deposito inicial    				*/
/*        Tarea: LEYCHEQUES-313-CU-1872   				*/
/*37 27/Jun/2012 J.Pazminno   SGC00002621  (LEYCHEQUES-313-CU-1874)     */
/*                            Validaciones estado deposito inicial      */
/*38 14/Nov/2013 Mar�a Jo. Silva Deposito Rapido  			*/
/*				Tarea: DEPMOV-AP-SGC00011785-SGC00011960*/
/*39 26/Marzo/2014  Mar�a Jo. Silva     Dep express   			*/
/*					Tarea: CTE-CC-SGC00014539  	*/
/*40 29/Jul/2014 Jorge Lino   Cambio en el proceso de ejecucion de los	*/
/*					archivos SRP(del SRP3 al SRP1)  */
/*					Tarea: RECA-CC-SGC00014719  	*/
/*41 05/Ago/2015 Galo Yanez	Permitir deposito normal en cuentas	*/
/*				de deposito especial			*/
/*				Tarea: DEESAT-AP-SGC00021113-SGC00021835*/
/*42 12/Ene/2016 Pablo Holguin  CTE-CC-SGC00023643 	UAF: Agregar	*/
/*					identificacion del depositante	*/
/*43 15/Sep/2016  Luis Banda    RECA-CE-SGC00026491 			*/
/*                Se reemplaza el valor que viene en Oficina por valor 0*/
/*  44 05/abr/2017 T.Cervantes Z. CTE-CC-SGC00027983 Guardar el nombre  */
/*                               de la persona que realiza el deposito. */
/*45 23/Abr/2018  Daniel Pereira  DEPONL-AP-SGC00031612-SGC00031669     */
/*46 01/ABR/2019 Paul Hoyos V. MPAC-AP-SGC00034749-SGC00034900 addestado*/
/*47 09/Ene/2020  Pablo Holguin   CTE-CC-SGC00037410  Estructura BCE 	*/
/*48 31/Ene/2020  Galo Yanez	Caja Verde				*/
/*				Tarea: CAJVER-AP-SGC00037659-SGC00037660*/
/*49 26/Feb/2021 Juan Carlos Velez  RECMPS-110  Migracion Latinia  	*/
/*50 11/Mar/2022 Maria Jose Silva	CNB-1 Validar canal		*/
/*51 11/Sep/2023 amaquilc	CNBM-46 CONTROL DE COMISION POR CNB  	*/
/*52 23/Nov/2023 Galo Yanez	CDS					*/
/*				Tarea: BLI-CC-SGC00048098		*/
/*53 06/Nov/2025  Maria Jo. Silva  CNBM-356  Registra Ced Depositante	*/
/*54 14/Sep/2026  Galo Yanez	Validar cupo cuando sea canal CNB	*/
/*				Tarea: GPR-19111			*/
/************************************************************************/

use cob_cuentas
go

if exists(select 1 from sysobjects where name = 'sp_tr_deposito_rc' and type = 'P')
begin
   drop procedure dbo.sp_tr_deposito_rc
   if exists (select 1 from sysobjects where name = 'sp_tr_deposito_rc' and type = 'P')
     print '<<< DROP PROCEDURE sp_tr_deposito_rc -- ERROR -- >>>'
    else
     print '== DROP PROCEDURE sp_tr_deposito_rc *OK* =='
end
go

create proc dbo.sp_tr_deposito_rc (
    @s_ssn      int,
    @s_srv          varchar(30),
    @s_lsrv         varchar(30),
    @s_user     varchar(30),
    @s_sesn         int=null,
    @s_term     varchar(10),
    @s_date     datetime,
    @s_ofi      smallint,   /* Localidad origen transaccion */
    @s_rol      smallint,
    @s_org_err  char(1) = null, /* Origen de error: [A], [S] */
    @s_error    int = null,
    @s_sev          tinyint = null,
    @s_msg      mensaje = null,
    @s_org      char(1),
    @t_corr     char(1) = 'N',
    @t_ssn_corr int = null, /* Trans a ser reversada */
    @t_debug    char(1) = 'N',
    @t_file     varchar(14) = null,
    @t_from     varchar(32) = null,
    @t_rty      char(1) = 'N',
    @t_trn      int,
    @p_lssn     int = null,
    @p_rssn     int = null,
    @p_rssn_corr    int = null,
    @p_slddisp  money   = null,
    @p_sldcont  money   = null,
    @p_nombre   varchar(30) = null,
    @p_envio    char(1) = 'N',
    @p_rpta         char(1) = 'N',
    @i_cta          cuenta,
    @i_efe          money,
    @i_prop         money=0,   /* lgr 12/28/1998  */
    @i_loc          money,
    @i_plaz         money=0,   /* lgr 12/28/1998 */
    @i_mon          tinyint,
    @i_sp           char(1) = 'N',
    @i_tsn          int = null,
    @i_autoriza     char(1)='N',
    @i_codigo       char(30) = null,    -- RCA 14/sep/2001
    @i_empresa      varchar(6) = null,  -- FMV 14/Jul/2004 -- RCA 25/Oct/2001.
    @i_des_cli      varchar(30)=  NULL, -- ref:esma05feb2003
    @i_factura      varchar(15) = NULL,  -- ref:esma05feb2003
    @i_cant_chq     int = null ,   --- ame 20.may.03
    @i_ubi          int = null,   --- ame 11/07/2003
    @o_nombre       varchar(30) out,
    @o_impuesto     money out,        /* lgr 12/10/1998 */
    @o_neto         money out,
    @o_ssn          int = 0 out,
    @o_consulta     int = 0 out,
    @i_ssn          int = null,  ---- sipecom actualizar reg consulta
    @i_date_off     datetime = null, -- JPM 30/Sep/2005
    @i_canal        varchar(5) = 'VEN', --REF 17
    @i_aplcobis     char(1) ='S', --ref 17
    @i_ruta_transito	    varchar(30) = null ,   --Ref038:msilvag
    --<REF 44
    @i_nomb_dep         varchar(24) = null,
    --REF 44>
    --<REF 52
    @e_cds           char(1) = null,		--GYC 2023/Nov/23
    --REF 52>    
    @o_novedad_sbs  char(1)         = 'N'   output,    -- JPM Ref 37
    @o_msg_error    varchar(132)    = null  output  ,   -- JPM Ref 37
    @o_fecha_contable	varchar(10)    = null out,	--Ref038:msilvag
    @i_iden_dep  	varchar(13) = null, --Ref42 Pholguiv
    @i_debito		money = null,  --ref45 dpereirv
    @i_val_consep	char(1) = null,	--ref45 dpereirv
    @i_denominaciones	varchar(250) ='', --Ref47 pholguiv
    @e_cod_trx	        int = 0,				--Ref 48 --GYC 2020/Ene/31
    @e_verde		char(1) = 'N',
    @e_uuid		varchar(255) = '',         
    --ini ref49
	@o_servicio_not 	varchar(5) = null out,	 
	@o_cod_ente      	varchar(20) = null out,	
	@o_celular       	varchar(10) = null out,	
	@o_correo        	varchar(64) = null out,	
	@o_valor	 	varchar(11) = null out, 
	@o_valor1	 	varchar(11) = null out, 
	@o_prod_deb      	char(3) = null out, 
	@o_cta_lat	 	char(3)  = null out	
    --fin ref49
)
as

declare @w_return               int,
    @w_return_2             int,
        @w_sp_name              varchar(30),
        @w_cuenta               int,
        @w_filial               tinyint,
        @w_oficina              smallint,
        --@w_filial_p             tinyint,
        --@w_oficina_p            smallint,
        --<REF 54
        @v_valida_cupo		money,		--GYC 2026/Sep/14
        --REF 54>             
        @w_producto             tinyint,
        @w_server_rem           descripcion,
        @w_server_local         descripcion,
        @w_tipo                 char(1),
        @w_factor               int,
        @w_sldcont              money,
        @w_slddisp              money,
        @w_nombre               varchar(30),
        @w_prod                 varchar(80),
        @w_signo                char(1),
        @w_oficina_cta          smallint,
        @w_tipo_contable    char(2), -- RCA 19/Abr/2002
        @w_impuesto             money,                          /* lgr 12/10/1998  */
        @w_neto                 money,
        --@w_maximo_c             money,
        @w_maximo_p             money,
        @w_minimo_p             money,
        @w_tipocta              char(1),
        @w_moneda_cta           tinyint,
        @w_moneda_caja          tinyint,
        @w_val_caja             money,
        @w_val2_caja            money,
        @w_val_usd_val2         money,
        @w_val_usd_neto         money,
        @w_saldo                money,                          /* JMO 11/06/2000 */
        @w_cupo_cli             money,                          /* JMO 11/06/2000 */
        @w_cliente              int,                            /* JMO 11/06/2000 */
        @w_desc_cli             varchar(150),                   /* JMO 11/06/2000 */
        @w_buzon                char(1),                        /* JMO 11/06/2000 */
        @w_utilizado            money,                          /* JMO 11/06/2000 */
        @w_estado               char(1),                        /* JMO 11/06/2000 */
        @w_oficial              int,                            /* JMO 11/06/2000 */
        @w_fecha_hoy            datetime,                       /* JMO 11/06/2000 */
        @w_tabla_valida         smallint,
        @w_origen_cta           char(3),  -- MSD 06/Junio/2002
        @w_empresa              int,
        --OPTIMIZACION POR CONTENCION DE LINEA 17/01/2003 FMV
        --Se Aumentan estas variables para ser pasadas al interno
        @wi_cedula              varchar(13),
        @wi_nombre              descripcion,
        @wi_prom1               money,
        @wi_prom2               money,
        @wi_prom3               money,
        @wi_prom4               money,
        @wi_prom5               money,
        @wi_prom6               money,
        @w_empresa_especial	int,					-- Ref. 41: -- GYC 2015/Ago/05
        @w_permite		char(1),				-- Ref. 41: -- GYC 2015/Ago/05
        @w_fecha_aper   datetime,   -- GYC 2012/May/30
        @wi_oficina_cta         int,
        @wi_oficial_cta         int,
        @w_tipo_bloqueo         char(3),  -- SIPECOM RCA
        @w_mensaje              mensaje ,
        @w_stat_ant_ca          char(1) ,  -- SIPECOM CVJ respalda status Cons_automa antes de cambio
        @w_status_ca            int,  -- CVJ Obtiene el status para ver si el deposito ya esta en consulta
        @w_tipocupo             catalogo, -- JPM 30/Sep/2005
        @w_existe_inhab         char(1),      -- JPM Ref. 37 ---> recuperar informacion inhabilidad SBS
        @w_tipo_cliente         char(1),
        @w_titular_inh          char(1),
        @w_firmante_inh         char(1),
        @w_fecinhab_ini         datetime,
        @w_fecinhab_fin         datetime,
        @w_otros_firmantes      int,
        @w_params               varchar(20),
        @w_raise_error          bit,
        @w_numrg                int,
        @w_causa_cierre         varchar(3) ,    -- <---- JPM Ref. 37
        @w_factura_aux      	varchar(15), --Ref42 Ene/15/2016
        @v_estado_canal			char(1)  --Ref050:msilvag 

/*  Captura nombre de Stored Procedure  */
select  @w_sp_name = 'sp_tr_deposito_rc',
    @w_fecha_hoy =  getdate(),
    @o_msg_error   = null,                         -- JPM Ref 37
    @o_novedad_sbs = 'N'                           -- JPM Ref 37


select @o_ssn = @s_ssn

--Ref050:msilvag Inicio
if @i_canal = 'CNB' and @s_user != 'cnb001'
begin
	
	--<REF 53
	select @i_iden_dep = @i_factura
	--REF 53>

	select @v_estado_canal = pa_char  
	from cobis..cl_parametro
	where pa_nemonico = 'ALCNB'
	if @@rowcount = 0
		 return 708153
	
	if @v_estado_canal != 'A'
		return 300003178

	if @t_corr = 'S'
	begin
		if exists(select 1 from cob_cuentas..cc_tran_monet
				where tm_sec_correccion = @t_ssn_corr 
				and tm_tipo_tran = 3040
				and tm_correccion = 'S'
				and tm_fecha = @s_date  
				and tm_canal = 'CNB' 
				and tm_usuario != 'cnb001' )
		begin
			exec cobis..sp_cerror
				@t_debug         = @t_debug,
				@t_file          = @t_file,
				@t_from          = @w_sp_name,
				@i_msg           = 'REGISTRO DUPLICADO',
				@i_num           = 130028
			return 130028
		end
	end
	
end
--Ref050:msilvag Fin

/*REF43 Inicio LBP */
if @i_canal = 'CNB'
   select @s_ofi = 0
/*REF43 Fin LBP */


/* Chequeo de errores generados remotamente */
if @s_org_err is not null           /*  Error del Sistema  */
begin
   select @o_consulta = 0   -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
   exec cobis..sp_cerror
        @t_debug        = @t_debug,
        @t_file         = @t_file,
        @t_from         = @w_sp_name,
        @i_num          = @s_error,
        @i_sev          = @s_sev,
        @i_msg          = @s_msg
   return 1

end

--Ref039:msilvag Inicio
if @i_codigo is null  --- verificar trn de deposito especial 3288 y 3289
Begin
	select @i_codigo =  a.valor from cobis..cl_catalogo a inner join cobis..cl_tabla b        --GYC 2001/OCT/15
		on a.tabla = b.codigo  and b.tabla = 'cc_canal_dep_express'
	where a.codigo = @i_canal
	and a.estado = 'V'
end
--Ref039:msilvag Fin


--Ref038:msilvag Inicio
/*if @i_canal != 'VEN'  and  isnull(@i_loc,0)  > 0
begin
	if @i_ruta_transito != '0'
	begin
		if substring(@i_ruta_transito,1,2) != '37' and
			exists (select 1 from cobis..cl_catalogo c inner join cobis..cl_tabla t
					on c.tabla = t.codigo
		    	   	where t.tabla =  'cl_canal_dep_rapido'
		    	   	and c.codigo = @i_canal and c.estado = 'V' )
		begin
			exec cobis..sp_cerror
				@t_debug         = @t_debug,
				@t_file          = @t_file,
				@t_from          = @w_sp_name,
				@i_num           = 300003401
			return 300003401
		end
	end
end*/
--Ref038:msilvag Fin


if exists (select 1 from cobis..cl_catalogo a
               inner join cobis..cl_tabla b        --GYC 2001/OCT/15
                  on a.tabla = b.codigo
           where b.tabla = 'cuentas_con_referencia'
         and a.codigo = @i_cta)
   begin
       if (@i_codigo = null and @t_corr = 'N')
       begin

            exec cobis..sp_cerror
                 @t_debug        = @t_debug,
                 @t_file         = @t_file,
                 @t_from         = @w_sp_name,
                 @i_num          = @s_error,
                 @i_sev          = @s_sev,
                 @i_msg          = 'ERROR ...... INGRESE CODIGO PARA ESTA CUENTA '
            return 1
       end
   end

/* Valida si se ha aperturado caja */
if @s_org = 'U' and @i_canal ='VEN' --ref 17
begin
      ---  ame 20.may.03
      exec @w_return = cob_remesas..sp_verifica_caja_rc
       @s_ssn   = @s_ssn,
       @s_srv   = @s_srv,
       @s_lsrv  = @s_lsrv,
       @s_user  = @s_user,
       @s_sesn  = @s_sesn,
       @s_term  = @s_term,
       @s_date  = @s_date,
       @s_ofi   = @s_ofi,
       @s_rol   = @s_rol,
       @s_sev   = @s_sev,
       @s_msg   = @s_msg,
       @s_org   = @s_org,
       @t_corr  = @t_corr,  --- ame 11/21/2003
       @t_trn   = @t_trn,
       @i_mon   = @i_mon,
       @i_cta   = @i_cta,  --- RCA 10/31/2003
       @i_ubi   = @i_ubi,  --- ame 11/10/2003
       @t_rty   = @t_rty,         -- JPM 30/Sep/2005 --->
       @i_date_off = @i_date_off  -- <--- JPM 30/sep/2005

        if @w_return != 0
	    begin
		select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
		return @w_return
	    end

end

-- OPTIMIZACION POR CONTENCION DE LINA 17/01/2003 FMV

select  @w_tipocta       = cc_tipocta,
        @w_cliente       = cc_cliente,
        @w_desc_cli      = cc_nombre,
        @w_cuenta        = cc_ctacte,
        @w_tipo_contable = cc_tipo_contable,
        @w_estado        = cc_estado,
    @wi_cedula       = cc_ced_ruc,
        @wi_nombre       = cc_nombre,
    @wi_prom1        = isnull(cc_promedio1,0),
    @wi_prom2        = isnull(cc_promedio2,0),
    @wi_prom3        = isnull(cc_promedio3,0),
    @wi_prom4        = isnull(cc_promedio4,0),
    @wi_prom5        = isnull(cc_promedio5,0),
    @wi_prom6        = isnull(cc_promedio6,0),
      @w_fecha_aper = cc_fecha_aper,      -- GYC 2012/May/30
        @wi_oficina_cta  = cc_oficina,
        @wi_oficial_cta  = cc_oficial,
        @w_origen_cta    = cc_origen,
        @w_filial    = cc_filial          -- JPM Ref 37
from cc_ctacte
where cc_cta_banco = @i_cta

if @@rowcount = 0
begin
     select @o_consulta = 0 -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
     if @i_aplcobis='S'
     begin
         exec cobis..sp_cerror
              @t_debug         = @t_debug,
              @t_file          = @t_file,
              @t_from          = @w_sp_name,
              @i_num           = 31004
     end
     return 31004

end
--PHOYOSV REF_46 INI 20190401
if @w_estado = 'T'
begin
   exec cobis..sp_cerror
           @t_debug     = @t_debug,
           @t_file      = @t_file,
           @t_from      = @w_sp_name,
           @i_num       = 128145,
           @i_sev       = 0,
           @i_msg       = 'ESTADO DE CUENTA NO PERMITE DEPOSITOS'
   return 128145
end
--PHOYOSV REF_46 FIN 20190401

select @w_tipo_bloqueo = cb_tipo_bloqueo
  from cob_cuentas..cc_ctabloqueada
 where cb_cuenta = @w_cuenta
   and cb_estado = 'V'
   and cb_tipo_bloqueo in ('1', '3')

if @@rowcount != 0
   begin
      select @w_mensaje = rtrim (valor)
        from cobis..cl_catalogo
       where tabla = (select codigo
                        from cobis..cl_tabla
                       where tabla = 'cc_tbloqueo')
         and codigo = @w_tipo_bloqueo

      select @w_mensaje = 'Cuenta bloqueada: ' + @w_mensaje


      select @o_consulta = 0    -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
      if @i_aplcobis ='S'
      begin
      exec cobis..sp_cerror
           @t_debug        = @t_debug,
           @t_file         = @t_file,
           @t_from         = @w_sp_name,
           @i_num          = 031008,
           @i_msg          = @w_mensaje
      return 031008           --GYC 2001/MAR/22
      end
      else
      return 031008
   end

--- REF18 smerino VALIDACI�N DE MONEDA EN EUROS EN CANAL ATM

 if @i_canal ='ATM' and @i_mon = 17

 begin

 if @i_aplcobis ='S'
      begin
      exec cobis..sp_cerror
           @t_debug        = @t_debug,
           @t_file         = @t_file,
           @t_from         = @w_sp_name,
           @i_num          = 300003340,   --300003339
           @i_msg          = @w_mensaje
      return 300003340          --SMERINO 2011/10/13
      end
      else
      return 300003340
   end
 ---smerino


--EAS1
-- Valida Deposito Inicial
--if @w_estado = 'D' and @t_corr = 'N'    -- JPM Ref 37: deshabilitar
if @w_estado = 'D'                        -- JPM Ref 37: cambiar secuencia de validacion
begin
  -- JPM Ref. 37 --->
  -- verificar informacion de firmas inhabilitadas SBS

  exec @w_return = cob_cuentas..sp_verifica_inhabilitacion_sbs
          @s_date             = @s_date,
          @t_debug            = @t_debug,
          @t_file             = @t_file,
          @t_from             = @t_from,
          @i_producto         = 'CTE',
          @i_cta_banco        = @i_cta,
          @i_procesado	      = 'N',
          @i_tr_atx	    = 'S', --Campo solo para atx
          @o_existe_inhab     = @w_existe_inhab     output,
          @o_tipo_cliente     = @w_tipo_cliente     output,
          @o_titular_inh      = @w_titular_inh      output,
          @o_firmante_inh     = @w_firmante_inh     output,
          @o_fecinhab_ini     = @w_fecinhab_ini     output,
          @o_fecinhab_fin     = @w_fecinhab_fin     output,
          @o_otros_firmantes  = @w_otros_firmantes  output
  if @w_return <> 0
    return @w_return

  -- analizar inhabilidad
  -- CASO 1: Cuenta con titular sancionado <<unico firmante autorizado>> ... CANCELAR CUENTA
  -- CASO 2: Cuenta con titulas sancionado AND alternos sancionados      ... CANCELAR CUENTA
  -- CASO 3: Cuenta con titulas sin sancion AND alternos sancionados     ... SEGUIR FLUJO NORMAL
  --         no se valida en sp porque no importa si alternante tiene sancion
  if @w_existe_inhab = 'S' and @w_titular_inh = 'S' and (@w_otros_firmantes = 0 or @w_firmante_inh = 'S')
  begin
    select @w_causa_cierre = '25'

    -- cancelar la cuenta
    begin tran
     update cob_cuentas..cc_ctacte
       set cc_estado = 'Q' -- cancelada
      where cc_cta_banco = @i_cta
     if @@error <> 0 or @@rowcount <> 1
     begin
       if @i_aplcobis='S'
       begin
         exec cobis..sp_cerror
                @t_debug        = @t_debug,
                @t_file         = @t_file,
                @t_from         = @w_sp_name,
                @i_num          = 35001
       end
       return 35001
     end

     -- cerrar detalle del producto
     update cobis..cl_det_producto
       set dp_estado_ser = 'C'
      where dp_cuenta = @i_cta
        and dp_producto = 3

     if @@error <> 0 or @@rowcount <> 1
     begin
       /* Error en actualizacion de registro en cl_det_producto */
       if @i_aplcobis='S'
       begin
         exec cobis..sp_cerror
                @t_debug      = @t_debug,
                @t_file       = @t_file,
                @t_from       = @w_sp_name,
                @i_num        = 105050
       end
       return 105050
     end

      /* Insert en Historico de Cierre   */
      exec @w_return = cobis..sp_cseqnos
              @t_debug      = @t_debug,
              @t_file       = @t_file,
              @t_from       = @w_sp_name,
              @i_tabla      = 'cc_his_cierre',
              @o_siguiente  = @w_numrg out
      if @w_return != 0
         return @w_return

      insert into cob_cuentas..cc_his_cierre
             (hc_secuencial, hc_cuenta, hc_causa, hc_saldo, hc_fecha,
              hc_filial, hc_oficina, hc_autorizante, hc_modo)
      values (@w_numrg, @w_cuenta, @w_causa_cierre, 0, @s_date,
              @w_filial, @wi_oficina_cta, @s_user, 'A')
      if @@error != 0
      begin
        if @i_aplcobis='S'
        begin
          exec cobis..sp_cerror
                    @t_debug  = null,
                    @t_file   = null,
                    @t_from   = @w_sp_name,
                    @i_num    = 33010
        end
        return 33010
      end


      /* Creacion de transaccion de servicio */
      -- OJO trx: 3013 --> CIERRE DE CUENTA CORRIENTE
      --          3830 --> CANCELACION DE CUENTAS CORRIENTES
      insert into cob_cuentas..cc_tscierre_cta
            (secuencial, tipo_transaccion, tsfecha, usuario, terminal, oficina, reentry, origen, secuencia,
             cta_banco, causa, saldo, fecha, autorizante, oficina_cta,hora, tipo_contable, otra_causa)
      values (@s_ssn, 3830, @s_date, @s_user, @s_term, @s_ofi, @t_rty, @s_org, @w_numrg,
              @i_cta , @w_causa_cierre, 0, @s_date, @s_user, @wi_oficina_cta, getdate(), @w_tipo_contable, @w_estado)
      if @@error != 0
      begin
       /* Error en creacion de transaccion de servicio */
       if @i_aplcobis='S'
       begin
         exec cobis..sp_cerror
               @t_debug   = null,
               @t_file    = null,
               @t_from    = @w_sp_name,
               @i_num     = 033005
       end
       return 033005
      end

    commit tran
    select @o_novedad_sbs  = 'S' -- marcar salida del procedimiento por novedad inhabilidad SBS
    select @w_params = convert(varchar, @w_fecinhab_ini, 101) + '@' + convert(varchar, @w_fecinhab_fin, 101)
    select @w_raise_error = 1   -- por default mensaje de error mostrar con raise error
    if @i_aplcobis = 'N'
      select @w_raise_error = 0 -- si aplication no cobis, desactivas raise error
    exec cobis..sp_error    -- manejador de error sin severidad
           @t_debug     = @t_debug,
           @t_file      = @t_file,
           @i_from      = @w_sp_name,
           @i_num       = 30018,
           --@i_params    = @w_params,
           @i_raise     = @w_raise_error,
           @o_msg       = @o_msg_error out

    return 30018
  end
  -- <--- JPM Ref. 37
  if @t_corr = 'N'
  begin
      select @w_val_usd_neto = isnull(@i_efe,0) + isnull(@i_loc,0)

      exec @w_return = cob_sbancario..sp_sb_valida_dep_inicial
          @t_debug    = @t_debug,
          @t_file     = @t_file,
          @i_producto = 3,
          @i_cta_banco= @i_cta,
          @i_dep      = @w_val_usd_neto,
          @i_aplcobis = @i_aplcobis
      if @w_return <> 0
      begin
          select @o_consulta = 0
          return @w_return
      end
  end
end

--  ----------- SE VALIDA EL CODIGO DE CTA EN CATALOGO cc_validacion_codigo  ----------
--  OPTIMIZACION DEL PARRAFO COMPLETO 17/01/2003 FMV
--  MSD 30/Mayo/2002
--  MSD 06/Junio/2002

      select @w_tabla_valida = codigo
      from   cobis..cl_tabla
      where  tabla = 'cc_validacion_codigo'

      --if exists( select 1         -- Ref 19: -- Dic 12/Dic/2011
       --          from cobis..cl_catalogo a,cobis..cl_tabla b
       --          where b.tabla  = 'cc_sublineas'
       --            and a.codigo = @i_codigo
       --            and a.tabla  = b.codigo )

      if exists (select 1 from cob_cuentas..cc_codigo_afecta_bce    -- Ref 20:  -- Feb 22/2012
           -- where ca_codigo_afecta = convert(int,@i_codigo)
           where convert(varchar,ca_codigo_afecta) = @i_codigo
             and ca_estado = 'A')

      begin
             if not exists (select 1
                            from   cobis..cl_catalogo
                            where  tabla = @w_tabla_valida
                            and    codigo = @w_origen_cta)
                begin
                   select @o_consulta = 0   -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
                   exec cobis..sp_cerror
                        @t_debug  = @t_debug,
                        @t_file   = @t_file,
                        @t_from   = @w_sp_name,
                        @i_msg    = 'ESTE ORIGEN DE CTA NO PERMITE USAR ESTE CODIGO',
                        @i_num    = 999999
                   return 1
                end
      end

-- OPTIMIZACION POR CONTENCION DE LINEA 17/01/2003
         if exists ( select 1
                     from cobis..cl_catalogo
                     where tabla  = @w_tabla_valida
                       and codigo = @w_origen_cta )
         begin
                -- OPTMIZACION POR CONTENCION DE LINEA 17/01/2003 FMV

						   if @w_origen_cta in ('6', '21') --jlb agregar el condicional del codigo de origen igual a 21


                begin
                    -- Ref 19: -- Dic 12/Dic/2011
                    --if not exists ( select 1
                    --      from cobis..cl_catalogo a, cobis..cl_tabla b
                    --      where b.tabla = 'cc_sublineas'
                    --        and a.codigo = @i_codigo
                    --        and a.tabla = b.codigo )
                    
                    if not exists (select 1 from cob_cuentas..cc_codigo_afecta_bce    -- Ref 20:  -- Feb 22/2012
                 -- where ca_codigo_afecta = convert(int,@i_codigo)
                 where convert(varchar,ca_codigo_afecta) = @i_codigo
                   and ca_estado = 'A')
                  begin
                     select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
                     exec cobis..sp_cerror
                        @t_debug  = @t_debug,
                        @t_file   = @t_file,
                        @t_from   = @w_sp_name,
                        @i_msg    = 'ESTE ORIGEN DE CTA NO ESTA ASOCIADO A ESTE CODIGO',
                        @i_num    = 999999
                     return 1
                  end
                end

         end

--  MSD 30/Mayo/2002
--  MSD 06/Junio/2002
--  FIN DE OPTIMIZACION DEL PARRAFO CONTROL DE CONTENCION 17/01/2003

/* Valido las transacciones no permitidas a cuentas rotativas ESA 08/09/2002 */
        exec @w_return = cob_cuentas..sp_val_ctas_rotativas
             @i_cta  = @i_cta,
             @i_trn  = @t_trn
        if @w_return <> 0
        begin
        select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
          if @i_aplcobis ='S'
          begin
                exec cobis..sp_cerror
                 @t_debug  = @t_debug,
                 @t_file   = @t_file,
                 @t_from   = @w_sp_name,
                @i_num    = @w_return
                end
                return @w_return
        end


/* WRB VALIDO DEPOSITO ESPECIAL */
--ini cmeg 16Agosto2006
if exists(select 1 from db_biz_admempresa..ba_tabla a
   inner join db_biz_admempresa..ba_catalogo b
      on tb_cod_tabla = ct_cod_tabla
  where tb_nom_tabla = 'ad_emp_dep_especial'
  and ct_cod_catalogo = @i_cta
  and ct_est_catalogo= 'A') and @i_sp = 'N'
	begin
	  select @w_empresa_especial = 0			-- Ref. 41: -- GYC 2015/Ago/05

	  select @w_empresa_especial = convert(int,ct_otro_campo_catalogo)
	  from db_biz_admempresa..ba_tabla a
       inner join db_biz_admempresa..ba_catalogo b
         on tb_cod_tabla = ct_cod_tabla
	  where tb_nom_tabla = 'ad_emp_dep_especial'
	    and ct_cod_catalogo = @i_cta
	    and ct_est_catalogo= 'A'

	  select @w_permite = 'N'

	  exec db_biz_admempresa..sp_con_parametroconf
		 @i_empresa          = @w_empresa_especial,  	-- Codigo de la empresa que se esta consultando
		 @i_producto         = 4,
		 @i_servicio         = 'REE',
		 @i_parametro        = 'DEPCUENTA',
		 @o_pa_val_booleano  = @w_permite out

	  if @w_permite = 'N'
	     begin
		  select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
		  exec cobis..sp_cerror
		       @t_debug  = @t_debug,
		       @t_file   = @t_file,
		       @t_from   = @w_sp_name,
		       @i_msg    = 'ERROR: ESTA TRANSACCION DEBE HACERLA POR DEPOSITO ESPECIAL',
		       @i_num    = 999999
		  return 1
	     end
	end
--fin cmeg 16Agosto2006
else
begin
  select @w_empresa = isnull(pe_empresa,0)
  from cob_pagos..pg_person_empresa
  where pe_cuenta = @i_cta

  if @w_empresa > 0 and @i_sp = 'N'
   begin
       if exists (select 1 from cobis..cl_catalogo a
         inner join cobis..cl_tabla b
            on b.codigo = a.tabla
         where b.tabla = 'cl_emp_depesp'
         and   a.codigo = convert(varchar(10),@w_empresa))
      begin
    select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
      exec cobis..sp_cerror
           @t_debug  = @t_debug,
           @t_file   = @t_file,
           @t_from   = @w_sp_name,
           @i_msg    = 'ERROR: ESTA TRANSACCION DEBE HACERLA POR DEPOSITO ESPECIAL',
           @i_num    = 999999
      return 1
      end
    end
end
-- Verifico la moneda de la cta con la que se registrara el mov  RE 29/ABR/2000
exec @w_return = cob_cuentas..sp_convierte_valor
     @i_valor        = @i_efe,
     @i_val2         = @i_loc,
     @i_moneda       = @i_mon,
     @i_tipocta      = 'CTE',
     @i_cta_banco    = @i_cta,
     @o_moneda_cta   = @w_moneda_cta out,
     @o_val_usd_neto = @w_val_usd_neto out,
     @o_val_usd_val2 = @w_val_usd_val2 out
if @w_return != 0
   begin
      select @o_consulta = 0    -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
      exec cobis..sp_cerror
           @t_debug         = @t_debug,
           @t_file          = @t_file,
           @t_from          = @w_sp_name,
           @i_msg           = 'ERROR EN LA RUTINA DE CONVERSION',
           @i_num           = 111111

      return 111111                 --GYC 2001/MAR/22
   end
else
   begin
      select @w_val_caja  = @i_efe
      select @w_val2_caja = @i_loc

      if @w_moneda_cta <> 0
         select @i_efe = @w_val_usd_neto,
                @i_loc = @w_val_usd_val2

      select @w_moneda_caja = @i_mon,
             @i_mon = @w_moneda_cta
   end

select @w_prod = 'CUENTA%CORRIENTE'



if @i_canal ='VEN'
begin

--print '0'
-- Captura de parametros de la oficina
exec @w_return = cobis..sp_parametros
     @t_debug        = @t_debug,
     @t_file         = @t_file,
     @t_from         = @w_sp_name,
     @s_lsrv         = @s_lsrv,
     @i_nom_producto = @w_prod,
     @o_filial       = @w_filial out,
     @o_oficina      = @w_oficina out,
     @o_producto     = @w_producto out,
     @o_server_local = @w_server_local
if @w_return != 0
    begin
        select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
        return @w_return
    end


-- Determinacion de condicion de local o remoto
exec @w_return = cob_cuentas..sp_cta_origen
     @t_debug        = @t_debug,
     @t_file         = @t_file,
     @t_from         = @w_sp_name,
     @i_cta          = @i_cta,
     @i_producto     = @w_producto,
     @i_mon          = @i_mon,
     @i_oficina      = @w_oficina,
     @o_tipo         = @w_tipo out,
     @o_srv_local    = @w_server_local out,
     @o_srv_rem      = @w_server_rem out
if @w_return != 0
    begin
        select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
        return @w_return
    end
end
else
begin
  select @w_tipo = 'L'
  select @w_producto = 3
  select @w_oficina =@s_ofi
end


if @w_tipo = 'L'
   select @w_server_local = @s_lsrv

/*  Modo de correccion  */
if @t_corr = 'N'
     select @w_factor = 1,  @w_signo = 'C'
else select @w_factor = -1, @w_signo = 'C'


/* OPTIMIZACION POR CONTENCION DE LINEA 17/01/2003 FMV
   Se lo desplaza al inicio del sp para evitar lecturas repetidas
   al maestro de cuentas.

select @w_tipocta  = cc_tipocta,            -- lgr 12/28/1998
       @w_cliente  = cc_cliente,                        -- JMO 11/06/2000
       @w_desc_cli = cc_nombre,                         -- JMO 11/06/2000
       @w_tipo_contable = cc_tipo_contable -- RCA 19/Abr/2002
 from cc_ctacte
where cc_cta_banco = @i_cta
--  and cc_moneda = 1   COMENTX
*/


if @i_autoriza = 'N' and @i_mon = 1 and @t_corr = 'N'      -- RE 03/MAY/2000
   begin
      select @w_maximo_p = pa_money                      -- RE 05/MAY/2000
        from cobis..cl_parametro
       where pa_nemonico = 'MDDP'
         and  pa_producto = 'CTE'

      select @w_minimo_p = pa_money                      -- RE 19/MAY/2000
        from cobis..cl_parametro
       where pa_nemonico = 'MMDP'
         and pa_producto = 'CTE'



      -- Modifica RCA 06/27/2001
      -- Eliminar control de Montos Maximos y Minimos.
      if ((@w_maximo_p <= (@i_efe + @i_loc)) or (@w_minimo_p >= (@i_efe + @i_loc)))
         --and @i_mon = 1
         and @w_moneda_caja = 0
         begin
    select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
    if @i_aplcobis='S'
    begin
        exec cobis..sp_cerror
       @t_debug        = @t_debug,
       @t_file         = @t_file,
       @t_from         = @w_sp_name,
       --@i_num          = 031002       CMH 11/Nov/1999
       @i_num          = 311819
    end
                return 311819
         end
      -- Fin modifica RCA
   end

-- Verificacion de deposito




if @i_efe > 0 and @t_corr = 'N'
   begin
--  print '--<Verificacion Deposito>--'
/*
    ----------->>>  CVJ Se actualiza el estatus de la consulta automatica como procesada
            para que no se presente en front end.
            Tambien se actualiza el campo bd_autorizado de la tabla cobis..cl_buzon_depositos
            con el valor de 'X' para que se vuelva a generar un registro y que se vaya nuevamente a consulta
*/
    if  @i_canal ='VEN' --ref 17
    begin
	if @i_ssn = 0
	 begin
		select @i_ssn = @s_ssn
	end

        exec @w_return = cob_cuentas..sp_cons_automatica_rc
                  @s_ssn               = @s_ssn,    -- Tenia @i_ssn
                  @s_user              = @s_user,
                  @s_ofi               = @s_ofi,
                  @s_rol               = @s_rol,
                  @t_trn               = @t_trn,
                  @i_ssn               = @i_ssn ,
                  @i_operacion         = 'U',
                  @i_status            = 'P',
                  @i_num_cuenta        = @i_cta,
                  @i_val_efectivo      = @i_efe,
                  @i_val_cheque        = @i_loc,
                  @i_codigo            = @i_codigo,
                  @i_empresa           = @i_empresa,
                  @i_factura           = @i_factura,
                  @i_cedula            = @wi_cedula,
                  @i_can_cheque        = @i_cant_chq ,
                  @i_ubi               = @i_ubi,   --- ame 11/10/2003
                  @i_tsn               = @i_tsn,   --- eas 12/06/2005
                  @o_stat_ant          = @w_stat_ant_ca out ,
                  @o_status_ca          = @w_status_ca out

            if @w_return <> 0
            begin
                select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
                exec cobis..sp_cerror
                    @t_debug        = @t_debug,
                    @t_file         = @t_file,
                    @t_from         = @w_sp_name,
                    @i_msg      = 'Error en el SP cob_cuentas..sp_cons_automatica_rc',
                    @i_num          = 11111
                        return @w_return
            end
    end
--  end

/*
    <<<-------------
*/


      exec @w_return = cobis..sp_verificacion_deposito_rc
           @s_date          = @s_date,
           @s_user          = @s_user,
           @s_rol           = @s_rol,
           @s_ofi           = @s_ofi,
           @s_ssn           = @s_ssn,
           @s_term          = @s_term,
       @s_srv           = @s_srv,
       @s_lsrv          = @s_lsrv,
       @s_sesn          = @s_sesn,
       @s_org           = @s_org,
           @t_trn           = @t_trn,
           @i_cliente       = @w_cliente,
           @i_tipocta       = 'CTE',
           @i_cta           = @i_cta,
           @i_efe           = @i_efe,
           @i_producto      = '3',
           @o_saldo         = @w_saldo out,
           @o_cupo          = @w_cupo_cli out,
           @o_buzon         = @w_buzon out,
           @o_utilizado     = @w_utilizado out,
           @o_oficial       = @w_oficial out,
           @i_can_cheque    = @i_cant_chq,
           @i_val_cheque    = @i_loc,
           @i_codigo        = @i_codigo,
           @i_empresa       = @i_empresa,
           @i_factura       = @i_factura,
           @i_ubi           = @i_ubi,   --- ame 11/10/2003
           @o_consulta      = @o_consulta out,
           @t_rty           = @t_rty,         -- JPM 30/Sep/2005 --->
           @i_date_off      = @i_date_off,    --
           @o_tipo_cupo     = @w_tipocupo out, -- <--- JPM 30/Sep/2005
           @i_canal = @i_canal

       --<REF 54						--GYC 2026/Sep/14
	if @i_canal = 'CNB'
	   begin
		select @v_valida_cupo = 0
		select @v_valida_cupo = @w_utilizado + @i_efe

		if @v_valida_cupo > @w_cupo_cli
		   begin
		     exec cobis..sp_cerror
			@t_debug         = @t_debug,
			@t_file          = @t_file,
			@t_from          = @w_sp_name,
			@i_msg           = 'CUPO EXCEDE EL CLIENTE',
			@i_num           = 39007
		     return 39007
		   end	     
	   end        
        --REF 54>  
                   
		--<REF 51
		if @i_canal = 'CNB'
			begin
				set @o_consulta = 0
			end
		--REF 51>	

      if @w_return <> 0
    begin
        select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
        return @w_return
    end


   end


--select @w_buzon = 'S'

--  Transaccion generada por usuario
if @s_org = 'U' or @s_org = 'D'
begin /*  Transaccion local  */

      if @w_tipo = 'L'
      begin

	--Ref42 Ene/15/2016 --Enviar la identificacion por el campo factura ya que no se lo esta utilizando,cuando es deposito
        --if @t_trn in (3040, 3288, 3553,3289)
        if @t_trn in (3040, 3288, 3553,3289, 4435)   --ref 45
        begin

             select @w_factura_aux = @i_factura

             if @i_canal  in ('WAP','SAT')  --Si son canlaes wap y sat toman la identificacion de la cuenta
                Select @i_factura =@wi_cedula,
                       --<REF 44
                       @i_nomb_dep = @wi_nombre
                       --REF 44>
             else
		Select @i_factura = @i_iden_dep
	end
	-------
--	print 'Ai_denominaciones%1!', @i_denominaciones

         exec @w_return = cob_cuentas..sp_tr_depo2_local_remoto_rc
              @s_ssn               = @s_ssn,
              @s_srv               = @s_srv,
              @s_user              = @s_user,
              @s_sesn              = @s_sesn,
              @s_term              = @s_term,
              @s_date              = @s_date,
              @s_ofi               = @s_ofi,
              @s_rol               = @s_rol,
              @t_corr              = @t_corr,
              @t_ssn_corr          = @t_ssn_corr,
              @t_debug             = @t_debug,
              @t_from              = @w_sp_name,
              @t_file              = @t_file,
              @t_rty               = @t_rty,
              @t_trn               = @t_trn,
              @p_rssn              = @p_rssn,
              @p_rssn_corr         = @p_rssn_corr,
              @s_org               = @s_org,
              @i_cta               = @i_cta,
              @i_efe               = @i_efe,
              @i_prop              = @i_prop,
              @i_loc               = @i_loc,
              @i_plaz              = @i_plaz,
              @i_mon               = @i_mon,
              @i_sp                = @i_sp,
              @i_oficina           = @w_oficina,
              @i_tsn               = @i_tsn,
              @i_mon_caja          = @w_moneda_caja,            -- RE 29/ABR/2000
              @i_val_caja          = @w_val_caja,               -- RE 29/ABR/2000
              @i_val2_caja         = @w_val2_caja,
              @i_codigo            = @i_codigo,         -- RCA 14/Sep/2001
              @i_des_cli           = @i_des_cli,                -- ref:esma05feb2003
              @i_factura           = @i_factura,                -- ref:esma05feb2003
              @o_slddisp           = @w_slddisp out,
              @o_nombre            = @w_nombre out,
              @o_sldcont           = @w_sldcont out,
              @o_oficina_cta       = @w_oficina_cta out,
              @o_impuesto          = @w_impuesto out,           /* lgr 12/10/1998 */
              @o_neto              = @w_neto out,
              @i_buzon             = @w_buzon,                  /* JMO 11/06/2000 */
              @i_cli               = @w_cliente,                /* JMO 11/06/2000 */
              @i_desc_cli          = @w_desc_cli,               /* JMO 11/06/2000 */
              @i_saldo             = @w_saldo,                  /* JMO 11/06/2000 */
              @i_cupo              = @w_cupo_cli,               /* JMO 11/06/2000 */
              @i_utilizado         = @w_utilizado,              /* JMO 11/06/2000 */
              @i_oficial           = @w_oficial,                /* JMO 11/06/2000 */
              @i_empresa           = @i_empresa,            -- RCA 25/OCT/2001
          -- OPTIMIZACION POR CONTENCION DE LINEA 17/01/2003 FM
              @i_estado            = @w_estado,
              @i_cedula            = @wi_cedula,
              @i_nombre            = @wi_nombre,
              @i_prom1             = @wi_prom1,
--            @i_prom1             = 'aaaa',      -- se a�adio esta linea para emular un error y verificar si se ejcutaba la actualizacion del status de consulta
              @i_prom2             = @wi_prom2,
              @i_prom3             = @wi_prom3,
              @i_prom4             = @wi_prom4,
              @i_prom5             = @wi_prom5,
              @i_prom6             = @wi_prom6,
              @i_fecha_aper    = @w_fecha_aper,   -- GYC 2012/May/30
              @i_oficina_cta       = @wi_oficina_cta,
              @i_oficial_cta       = @wi_oficial_cta,
              @i_cant_chq          = @i_cant_chq,      --- ame 20.may.03
              @i_ubi               = @i_ubi,            --- ame 11/10/2003
              @i_date_off          = @i_date_off,       -- JPM 30/Sep/2005 --->
              @i_tipo_cupo         = @w_tipocupo,        -- <--- JPM 30/Sep/2005
              @i_canal       = @i_canal,  --ref 17
              @i_aplcobis    = @i_aplcobis  ,--ref 17
              --<REF 44
              @i_nomb_dep         = @i_nomb_dep,
              --REF 44>
              --<REF 52
              @e_cds         = @e_cds,		-- GYC 2023/Nov/23
              --REF 52>              
              @o_fecha_contable	   = @o_fecha_contable  out, --Ref038:msilvag
              @i_debito = @i_debito,  --ref45 dpereirv
              @i_val_consep = @i_val_consep,  --ref45 dpereirv
              @i_denominaciones	   = @i_denominaciones,  --Ref47
    	      @e_cod_trx	  = @e_cod_trx,				--Ref 48 --GYC 2020/Ene/31
    	      @e_verde	          = @e_verde,
    	      @e_uuid	          = @e_uuid,
    	      --ini ref49
	      @o_servicio_not      = @o_servicio_not out,	 
	      @o_cod_ente          = @o_cod_ente out,				
	      @o_celular           = @o_celular out,	
	      @o_correo            = @o_correo out,	
	      @o_valor             = @o_valor out, 
	      @o_valor1            = @o_valor1 out,
	      @o_prod_deb          = @o_prod_deb out, 
	      @o_cta_lat           = @o_cta_lat out	
    	      --fin ref49
	      



	---Ref42 Recupera valor variable
	--if @t_trn in (3040, 3288, 3553,3289)
	if @t_trn in (3040, 3288, 3553,3289, 4435) --ref45
	select @i_factura= @w_factura_aux

       --TPE 27/10/2004 Retorno a variables
        select @o_nombre = @w_nombre
        select @o_impuesto = @w_impuesto
        select @o_neto = @w_neto

/*
        ----------->>>  CVJ: Si se produjo un error en la transaccion y ya se actualizo el estatus de
                consulta automatica como PROCESADA se vuelve a su estatus anterior.
                Tambien se respaldo el mensaje de error del cob_cuentas..sp_tr_depo2_local_remoto_rc
                en caso de que exista y luego del reverso del estatus se hace su respectivo return
*/
        select @w_return_2 = @w_return

         if @i_ssn is not null  and ( @w_return_2 <> 1 and @w_return_2 <> 0 ) and  @i_canal ='VEN'  --ref 17
        begin

	    select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
            exec @w_return = cob_cuentas..sp_cons_automatica_rc
                        @s_ssn               = @s_ssn,   -- Tenia @i_ssn
                @s_user              = @s_user,
                @s_ofi               = @s_ofi,
                @s_rol               = @s_rol,
                @t_trn               = @t_trn,
                @i_operacion         = 'U',
                @i_ssn           = @i_ssn ,
--              @i_status            = @w_stat_ant_ca ,
                @i_status            = 'X' ,
                @i_num_cuenta        = @i_cta,
                @i_val_efectivo      = @i_efe,
                @i_val_cheque        = @i_loc,
                @i_codigo        = @i_codigo,
                @i_empresa       = @i_empresa,
                @i_factura       = @i_factura,
                @i_cedula        = @wi_cedula,
                @i_can_cheque    = @i_cant_chq,
                @i_ubi           = @i_ubi   --- ame 11/10/2003

                if @w_return <> 0
                begin
                    select @o_consulta = 0  -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
                    exec cobis..sp_cerror
                        @t_debug        = @t_debug,
                        @t_file         = @t_file,
                        @t_from         = @w_sp_name,
                        @i_msg      = 'Error en el SP cob_cuentas..sp_cons_automatica_rc',
                        @i_num          = 311819
                            return @w_return
                end

            end
/*
        <<<-------------
*/
        if @w_return_2 <> 0 and @w_return_2 <> 1
            select @o_consulta = 0

        return @w_return_2


        /****if @w_return <> 0 ***/

        end


      /*  Transaccion remota  */
      if @w_tipo = 'R'
         begin        /*  Envio de transaccion remota  */
            exec cobis..sp_begin_secure_submit  @i_toserver = @w_server_rem
                 select  p_lssn      = @s_ssn,
                         p_envio     = 'S',
                         p_rssn_corr = (select tm_remoto_ssn
                                          from cc_tran_monet
                                         where tm_secuencial = @t_ssn_corr)
            exec @w_return = cobis..sp_end_secure_submit @i_wait = 'S'
            return 0
         end
   end


/*  Transaccion submitida desde otro regional  */
if @s_org = 'S'
begin /*  Transaccion Local  */
   if @w_tipo = 'L'
      begin

        --if @t_trn in (3040, 3288, 3553,3289 )
        if @t_trn in (3040, 3288, 3553,3289, 4435) --ref 45
        begin
		select @w_factura_aux = @i_factura
		Select @i_factura = @i_iden_dep
	end
	 
         exec @w_return = cob_cuentas..sp_tr_depo2_local_remoto_rc
              @s_ssn               = @s_ssn,
              @s_srv               = @s_srv,
              @s_user              = @s_user,
              @s_sesn              = @s_sesn,
              @s_term              = @s_term,
              @s_date              = @s_date,
              @s_ofi               = @s_ofi,
              @s_rol               = @s_rol,
              @t_corr              = @t_corr,
              @t_ssn_corr          = @t_ssn_corr,
              @t_debug             = @t_debug,
              @t_from              = @t_from,
              @t_file              = @t_file,
              @t_rty               = @t_rty,
              @t_trn               = @t_trn,
              @p_lssn              = @p_lssn,
              @p_rssn              = @p_rssn,
              @p_rssn_corr         = @p_rssn_corr,
              @s_org               = @s_org,
              @i_cta               = @i_cta,
              @i_efe               = @i_efe,
              @i_prop              = @i_prop,
              @i_loc               = @i_loc,
              @i_plaz              = @i_plaz,
              @i_mon               = @i_mon,
              @i_sp                = @i_sp,
              @i_oficina           = @w_oficina,
              @i_tsn               = @i_tsn,
              @i_codigo            = @i_codigo,         -- RCA 14/Sep/2001
              @i_empresa           = @i_empresa,        -- RCA 25/OCT/2001
              @i_des_cli           = @i_des_cli,  -- ref:esma05feb2003
              @i_factura           = @i_factura,   -- ref:esma05feb2003
              @o_slddisp           = @w_slddisp out,
              @o_nombre            = @w_nombre out,
              @o_impuesto          = @w_impuesto out,           /* lgr 12/10/1998 */
              @o_neto              = @w_neto out,
              @o_sldcont           = @w_sldcont out,
              @o_oficina_cta       = @w_oficina_cta out,
          -- OPTIMIZACION POR CONTENCION DE LINEA 17/01/2003 FM
              @i_estado            = @w_estado,
              @i_cedula            = @wi_cedula,
              @i_nombre            = @wi_nombre,
              @i_prom1             = @wi_prom1,
              @i_prom2             = @wi_prom2,
              @i_prom3             = @wi_prom3,
              @i_prom4             = @wi_prom4,
              @i_prom5             = @wi_prom5,
              @i_prom6             = @wi_prom6,
              @i_fecha_aper    = @w_fecha_aper,   -- GYC 2012/May/30
              @i_oficina_cta       = @wi_oficina_cta,
              @i_oficial_cta       = @wi_oficial_cta,
              @i_cant_chq          = @i_cant_chq,     --- ame 20.may.03
              @i_ubi               = @i_ubi       ,     --- ame 11/10/2003
               @i_canal           = @i_canal,  --Ref038:msilvag
              --<REF 44
              @i_nomb_dep         = @i_nomb_dep,
              --REF 44>
              --<REF 52
              @e_cds         = @e_cds,		-- GYC 2023/Nov/23
              --REF 52>                 
              @o_fecha_contable	   = @o_fecha_contable  out, --Ref038:msilvag
              @i_debito = @i_debito,
              @i_denominaciones	   = @i_denominaciones,  --Ref47
    	      @e_cod_trx	  = @e_cod_trx,				--Ref 48 --GYC 2020/Ene/31
    	      @e_verde	          = @e_verde,
    	      @e_uuid	          = @e_uuid,                
	      --ini ref49
	      @o_servicio_not      = @o_servicio_not out,	 
	      @o_cod_ente          = @o_cod_ente out,				
	      @o_celular           = @o_celular out,	
	      @o_correo            = @o_correo out,	
	      @o_valor             = @o_valor out, 
	      @o_valor1            = @o_valor1 out,
	      @o_prod_deb          = @o_prod_deb out, 
	      @o_cta_lat           = @o_cta_lat out	
    	      --fin ref49

         if @w_return <> 0
            return @w_return

     --TPE 27/10/2004 Retorno a variables
         select @o_nombre = @w_nombre
         select @o_impuesto = @w_impuesto
         select @o_neto = @w_neto

         /*  Envio de Resultados  */
         exec @w_return = cobis..sp_begin_resubmit
              @i_toserver = @s_srv,
              @i_touser   = @s_user,
              @i_tosesion = @s_sesn

         if @w_return <> 0
            return @w_return

         select  p_rpta  = 'S',
                 p_rssn = @s_ssn,
                 p_sldcont = @w_sldcont,
                 p_slddisp = @w_slddisp,
                 p_nombre = @w_nombre
         exec @w_return = cobis..sp_end_resubmit

        if @w_return <> 0
            return @w_return
      end

   /*  Transaccion remota:  Error */
   if @w_tipo = 'R'
      begin
     select @o_consulta = 0 -- CVJ Setear a la variable @o_consulta = 0 cuando se produce un error en cualquier caso que o sea consulta
         exec cobis..sp_cerror
              @t_debug        = @t_debug,
              @t_file         = @t_file,
              @t_from         = @w_sp_name,
              --@i_num          = 031002       CMH 11/Nov/1999
              @i_num          = 311819
         return 311819
      end
end

return 0
go


if exists(select 1 from sysobjects where name='sp_tr_deposito_rc' and type = 'P')
  PRINT '== CREATE PROCEDURE sp_tr_deposito_rc *OK* =='
 else
  PRINT '<<< CREATE PROCEDURE sp_tr_deposito_rc -- ERROR -- >>>'
go
