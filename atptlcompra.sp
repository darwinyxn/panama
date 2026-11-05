/****************************************************************************/
/* Archivo:				atptlcompra.sp                     					*/
/* Motor de Base:		SYBASE												*/
/* Base de datos: 		cob_atm                                             */
/* Servidor:			HP-ACT												*/
/* Aplicacion:			ATM	   												*/
/* Stored procedure: 	sp_at_ptl_compra                        			*/
/* Procesamiento:		OLTP												*/
/* Ult.ControlTarea:    R-PTD-AP-SGC00048101-SGC00050239					*/
/* Ult.Referencia:		REF 20												*/
/* Disenado por: 		Pastor Quintero M.                               	*/
/* Fecha de escritura: 	30/MAY/2012                                         */
/****************************************************************************/
/* 								IMPORTANTE                                  */
/* Este  programa  es  parte  de los paquetes  bancarios  propiedad del     */
/* BANCO BOLIVARIANO S.A.                                                   */
/* Su uso no autorizado queda expresamente prohibido así como cualquier     */
/* alteración o agregado hecho por alguno de sus usuarios sin el debido     */
/* consentimiento   por  escrito  de  la   Presidencia  Ejecutiva   del     */
/* BANCO BOLIVARIANO S.A. o su representante.                               */
/*                                                                          */
/****************************************************************************/
/* PROPOSITO:                                                               */
/* Este sp esta deseñado para poder ejecutar los sp de compra desde POSTILIO*/
/* sp_at_compra_ah                                                          */
/* sp_at_compra_cc                                                          */
/* sp_at_compra_vr                                                          */
/****************************************************************************/
/* MODIFICACIONES:                                                          */
/****************************************************************************/
/* REF	FECHA       AUTOR        TAREA			                            */
/* 30/MAY/2012 Pastor Quintero M.         Versión inicial                   */
/*--------------------------------------------------------------------------*/
/* 26/SEP/2012 Miguel Behr L.             CAJ-CC-SGC00004633                */
/*                                        Aprobar las trx de anulacion de   */
/*                                        compras                           */
/* 14/ENE/2013 Juan Carlos Veliz        SGC00006826 Migracion Credimatic    */
/* 16/JUL/2013  Juan Carlos Veliz   Control StandIn Postilion               */
/*                                  CAJ-CC-SGC00010230                      */
/* 11/Dic/2013 JC Veliz G.      CAJ-CE-SGC00012828                          */
/*                              Actualizacion Fecha Hora Real Trx OFFLINE   */
/* 29/Abril/2014 JCVeliz        CAJ-CC-SGC00014914                          */
/*                              Aplicar Promocion de Compras POS MEDIANET   */
/* 03/Julio/2014 JCVeliz        CAJ-CC-SGC00017088                          */
/*                          REF: JVG-20140812-SGC00017088                   */
/*                       Proyecto Deflactacion de IVA de Comision Gasolinera*/
/*                          Se incluye optimizar proceso de compras         */
/*                          por recomendacion de QADBA y tambien al req.    */
/*                          al proceso de deflactacion de IVA y comision    */
/*                          en gasolineras                                  */
/*--------------------------------------------------------------------------*/
/* 16/Jun/2016 Marcelo Gaona    CAJ-CC-SGC00025324                          */
/*                       Considerar el cobro del ISD para las transacciones */
/*                         de compras en el exterior.                       */
/*                         ref-MGT20160616-ISD                              */
/*----------------------------------------------------------------------------*/
/* 01/JUN/2017 Juan Carlos Veliz Garcia     CEXITD-AP-SGC00026995-SGC00028689 */
/*                         Proyecto Compras Internacionales                 */
/*                         Nuevos Campos para los SP de compras AHO,CTE, VIRT */
/*                         Nuevos parametros al SP de sp_at_ptl_compra      */
/*                         Validacion para comision de compra internacional */
/*                         REF-JCV20170601COMPEXTERIOR                      */
/*--------------------------------------------------------------------------*/
/* 02/Abril/2018 Juan Carlos Veliz Garcia   CNPTD-AP-SGC00031422-SGC00031425*/
/*                         Proyecto Compras WEB                             */
/*                         REF-20180402_COMPRAWEB                           */
/*----------------------------------------------------------------------------*/
/* 26/Marzo/2019 Ana M. Morales Oliú	CAJ-CE-SGC00034933					*/
/* 						   Ajuste al proceso de compras para excluir las    */
/*						   transacciones de compras de verificacion de cuenta */
/*							de la estructura E02.					  		*/
/*						   REF-AMMO20190326_COMPRAWEB_E02                   */
/*----------------------------------------------------------------------------*/
/* 06/07/2018   Joel Lozano      Cambios Cubo Débito Autorizaciones         */
/*                                                CAJ-CC:SGC00035932        */
/*----------------------------------------------------------------------------*/
/* 08/SEP/2020	Danny Quimis 	CAJ-CC-SGC00038949							*/
/*								IVA Servicios Digitales						*/
/*								ref-20200908-IVASERDIG						*/
/*----------------------------------------------------------------------------*/
/* 22/JUN/2021	Luis Sanchez L. 	CAJ-CE-SGC00041850			  			*/
/*									Ajuste inconsistencia autorizacion		*/
/*----------------------------------------------------------------------------*/
/* 30/AGO/2021	Luis Sanchez L. 	CAJ-CE-SGC00042415			  			*/
/*									Ajuste validacion registro existente	*/
/*----------------------------------------------------------------------------*/
/* 14/Oct/2021 Luis Sanchez L.		CAJ-CC-SGC00042296		  				*/
/* 									Mejoras Reversos TD inactiva     		*/
/*----------------------------------------------------------------------------*/
/* 06/Dic/2021 Luis Sanchez L.		ATM-CC-SGC00043061		  				*/
/* 									Mejoras Reversos Dias Posteriores 		*/ 
/*----------------------------------------------------------------------------*/
/* 22/Abr/2022 Luis Sanchez L.		CAJ-CE-SGC00044330				  		*/
/* 									Ajuste Rev Dias Posteriores Mdnet 		*/ 
/*----------------------------------------------------------------------------*/
/* 19	14/Jul/2022	lsanchel		SGC00043955 				  			*/
/* 		Autorizaciones Parciales 		 		  							*/ 
/*----------------------------------------------------------------------------*/
/* 20	23/Sep/2024	lsanchel		PTD-AP-SGC00048101-SGC00050239 			*/
/* 		Procesamiento TD Fase 1 		 		  							*/ 
/*--------------------------------------------------------------------------*/
/* 21	16/Abr/2026	aproanoa		GPR-14882		                        */
/* 		Agregar nuevo motivo E02		 		  							*/  
/****************************************************************************/

use cob_atm
go

if exists(select 1 from sysobjects where name = 'sp_at_ptl_compra' and type = 'P')
begin
   drop procedure dbo.sp_at_ptl_compra
end
go

create procedure dbo.sp_at_ptl_compra
    @i_oficina              int         = 0,            -- Oficina del cajero o de la red (Banred, Medianet,Credimatic)
    @i_trn                  int,                        -- código de la transacción
    @i_cajero               varchar(8)  = null,         -- Código Interno de la Terminal
    @i_atm_secuencial       int,                        -- Secuencial de la terminal
    @i_fecha_trans          datetime,                   -- fecha de la transacción
    @i_fecha_contable       datetime,                   -- fecha contable
    @i_fecha_concilia       datetime    = '01/01/1900', -- fecha de conciliación 
    @i_fecha_real           datetime,                   -- fecha del sistema
    @i_cod_tarjeta          int,                        -- código interno de la tarjeta
    @i_tarjeta              varchar(19) = null,         -- numero de la tarjeta  
    @i_origen               varchar(5)  = 'MDNTE',      -- valor del origen de la transaccion (BOLIV,VISA,MDNTE,BANRE)
    @i_cuenta_debito        varchar(24) = '0000000000', -- número de cuenta a debitar
    @i_cuenta_credito       varchar(24) = '0000000000', -- número de cuenta acreditar
    @i_reentry              char(1)     = 'N',          -- Indicador de reentry 'S' o 'N'
    @i_reverso              char(1)     = 'N',          -- Indicador de reverso 'S', 'N'
    @i_empresa              smallint    = 0,            -- código de empresa
    @i_moneda               varchar(4)  = '840',        -- código ISO de la moneda
    @i_valor                money       = 0,            -- monto de la transacción
    @i_comision             money       = 0,            -- monto de la comisión 
    @i_autorizacion         varchar(6)  = null,         -- código de autorización
    @i_pais                 varchar(3)  = 'EC',         -- código del país
    @i_solicitud_recibo     char(1)     = 'N',          -- Indicador si el usuario solicito la impresión del recibo
    @i_dispositivo          char(2)     = '01',         -- Terminal Type --> 00 Administrative terminal, 01 POS terminal,02 ATM, 03 Home terminal ...
    @i_iso_field3           varchar(6)  = null,         -- valor del campo ISO field3  --> FIELD 3—PROCESSING CODE
    @i_iso_field22          varchar(3)  = null,         -- valor del campo ISO field22  --> FIELD 22—POS Entry Mode CAMPO NUEVO PARA MEDIANET
    @i_iso_field18          varchar(4)  = null,         -- valor del campo ISO field18 --> FIELD 18—MERCHANT TYPE
    /*<REF 19 @i_iso_field19          varchar(4)  = null,    REF 19>*/     
	-- valor del campo ISO field19 --> FIELD 19—ACQUIRING INSTITUTION COUNTRY CODE
    @i_iso_field32          varchar(14) = null,         -- valor del campo ISO field32 --> FIELD 32—ACQUIRING INSTITUTION IDENTIFICATION CODE (ABA)
    @i_iso_field42          varchar(15) = null,         -- valor del campo ISO field42 --> FIELD 42—CARD ACCEPTOR IDENTIFICATION CODE
    @i_iso_field43          varchar(40) = null,         -- valor del campo ISO field43 --> FIELD 43—CARD ACCEPTOR NAME/LOCATION
    /*<REF 19 @i_iso_field51          varchar(4)  = null,  REF 19>*/       
	-- valor del campo ISO field51 --> FIELD 51—CURRENCY CODE, CARDHOLDER BILLING
    @i_iso_field59          varchar(15) = null,         -- valor del campo ISO field59 --> FIELD 59—NATIONAL POINT-OF-SERVICE GEOGRAPHIC DATA
    @i_iso_field108         varchar(17) = null,         -- valor del campo ISO field108 (valor acumulado)  ---ref-MGT20160616-ISD
    @i_iso_field109         varchar(17) = null,         -- valor del campo ISO field109  (tipo documento/numero de documento) --ref-MGT20160616-ISD
    @i_iso_field112         varchar(120)= null,         -- Campo privado usado por medianet -->  Informacion del diferido
    @i_iso_field114         varchar(120)= null,         -- Campo privado usado por medianet --> Usado por medianet contiene el numero del lote
    @i_iso_field119         varchar(120)= null,         -- Campo privado usado por medianet --> Informacion monto base IVA
    @i_iso_field120         varchar(120)= null,         -- Campo privado usado por medianet --> Informacion adicional
    @i_monto_fuente         money=0,                    -- monto fuente de la transaccion  REF-JCV20170601COMPEXTERIOR
    @i_moneda_fuente        varchar(3) =null,           -- codigo fuente de la transaccion  REF-JCV20170601COMPEXTERIOR
    @i_iso_field25          varchar(3) =null,           -- POS Condition Code,  REF-20180402-COMPRAWEB
    @i_iso_field60ECI       varchar(3) =null,           -- POS Condition Code,  REF-20180706-CUBO AUTORIZACION JLF  CAJ-CC:SGC00035932  
	@i_auth_reason			char(1)='',					-- Razon de autorizacion standin --CAJ-CE-SGC00041850
	--<REF 19
	@i_valor_auth			money = 0,					--REF 19> Monto autorizado de la transaccion 
    --definicion de los parametros de Salida
    @o_codigo_error         int             = 999999    out,    -- código de error
    /*<REF 19 @o_atm_secuencial       int             = 0         out, REF 19>*/    
	-- secuencial  ==> ssn 
    @o_saldo_disponible     money           = 0         out,    -- Saldo disponible en débito
    @o_saldo_contable       money           = 0         out,    -- Saldo contable en débito
    @o_saldiscr             money           = 0         out,    -- Saldo disponible en crédito
    @o_autorizacion         varchar(6)      = null      out,    -- Numero de autorización
    @o_mensaje              varchar(255)    = ''        out,    -- mensaje
    @o_nombre               varchar(40)     = ' '       out,
    @o_indicador_ganador    char(1) ='N' out,  
    @o_iso_field108resp     varchar(17) = 'N'       out     -- Indicador de acumulacion S=trx autorizada / N= trx negada  --ref-MGT20160607-ISD	
as
begin
    --==============================================================
    --print '-- declaracion  de variables  locales'
    --==============================================================
    declare @w_return           int,
            @w_ssn              int,
            @w_sec_host         int,
            @w_aba_banco        int,
            @w_contador_bb      int,
            @w_contador_red     int,
            @w_trn_cob          int,
            @w_cliente          int,
            @w_secuencial       int,
            @w_empresa          smallint,
            @w_rol              smallint,
            @w_empresa_aut      smallint,
            @w_empresa_trj      smallint,
            @w_fi_banco         smallint,
            @w_moneda           tinyint,
            @w_dispositivo      tinyint,
            @w_fechap           datetime,
            @w_comision         money,
            @w_tasa_conversion  money,
            @w_lvalor           money,
            @w_salconcr         money,
            @w_offline          char(1),
            @w_aplcobis         char(1),
            @w_ind_exon         char(1),
            @w_veri_tarjeta     char(1),
            @w_gen_autoriza     char(1),
            @w_signo_trn        char(1),
            @w_cobro            char(1),
            @w_indcob_isd_ret   char(1),
            @w_indcob_isd_cmp   char(1),
            @w_canal            char(3),
            @w_fecha_param      char(10),
            --@w_cobrar_comision  varchar(1), QA SGC00042415
            @w_codcosto         varchar(2),
            --@w_tipo_cuenta      varchar(2),
            @w_causal_cob       varchar(3),
            --@w_red_origen       varchar(4),
            @w_num_lote         varchar(7),
            @w_ced_ruc          varchar(13),            
            @w_tarjeta          varchar(24),
            @w_srv              varchar(30),
            @w_sp_name          varchar(30),
            @w_referencia2      varchar(40),
            -- Variables at_ruteo_tran 
            @w_ttrn             int, --ATM-CC-SGC00043061	smallint > int
            @w_proddeb          descripcion,
            @w_prodcre          descripcion,
            @w_veri_cupo        char(1),
            @w_tipo_cupo        char(1),            
            @w_causa            varchar(3),
            @w_mensaje_atm      char(1),
            @w_ind_comision     char(1),
            @w_promocion        char(1),
            @w_notificaSMS      char(1),
            @w_retardo_SMS      char(1),
            @w_ind_isd          char(1),
            -- Variable genera costo
            @w_valor_isd         money,
            @w_porcentaje_isd    float,
            @w_fecha_ult_mov     datetime,
            @w_fecha_ult_mov_tar datetime,
            @w_fecha_ult_mov_cta datetime,
            @w_rpc               descripcion,
            -- Variable tarjeta
            --@w_sec_tarjeta        int,
            @w_tipo_tarjeta       char(64),
            @w_codigo_propietario int,
            @w_nombre_tarjeta     varchar(30),
            @w_tarjeta_principal  int,
            @w_terminal           varchar(10),
            -- validar cupo
            @w_periodicidad_cupo            char(1),    -- pqm actualizacion del cupo de la cuenta
            @w_saldo_cupo                   money,      -- pqm actualizacion del cupo de la cuenta
            @w_saldo_cupo_cta               money,      -- pqm actualizacion del cupo de la cuenta 
            @w_cupo_compras_utilizado       money,      -- pqm actualizacion del cupo de la cuenta
            @w_cupo_compras_utilizado_cta   money,      -- pqm actualizacion del cupo de la cuenta
            @w_transacciones_usadas_cta     tinyint,    -- pqm actualizacion del cupo de la cuenta 
            @w_transacciones_usadas         tinyint,    -- pqm actualizacion del cupo de la cuenta
            @w_cupo_online                  money,      -- pqm actualizacion del cupo de la cuenta 
            @w_cupo_online_cta              money,      -- pqm actualizacion del cupo de la cuenta
            @w_referencia                   varchar(40), ----REF-20180402_COMPRAWEB  
            @w_referencia5                  varchar(40) ,
            @w_message_ganador varchar(50),            ---JCGV CAJ-CC-SGC00014914
            @w_indicador_ganador char(1),                  ---JCGV CAJ-CC-SGC00014914
            @w_iterador int, @w_len_campo int,@w_tipo_campo char(1), ---REF JVG-20140812-SGC00017088
            @w_valorcampo money,@w_valor_iva  money, @w_valor_servicio money, @w_valor_propina money , @w_valor_interes money, ---REF JVG-20140812-SGC00017088
            @w_valor_monto_fijo money,                              ---REF JVG-20140812-SGC00017088 DEFLACTACION IVA GASOLINERA
            @w_valor_debito1 money,@w_valor_debito2 money,      ---REF JVG-20140812-SGC00017088 DEFLACTACION IVA GASOLINERA
            @w_monto_graba_iva money, @w_monto_no_graba_iva money,  ---REF JVG-20140812-SGC00017088 DEFLACTACION IVA GASOLINERA
            @w_valor_comision_credim_gas money  ,@w_referencia4  varchar(40),@w_valor_referencia2 varchar(40), @w_valor_comision_medianet_gas money,
            
            @w_valor_base_ids                       money,          -- campo de trabajo  --ref-MGT20160616-ISD
            @w_monto_acum_isd               money,          -- monto acumulado   --ref-MGT20160616-ISD
            @w_tipo_docum_isd               varchar(2),     -- Tipo de documento (01=cedula / 02=pasaporte / 03= Cextranjero / 04=ruc) --ref-MGT20160616-ISD
            @w_nume_docum_isd               varchar(15),    -- Numero del documento --ref-MGT20160616-ISD
            @w_monto_tota_isd               money,          -- valor acumalado mas valor de la transaccion   --ref-MGT20160616-ISD
            @w_monto_dife_isd               money,          -- valor sobre  el que se debe cobrar el ISD --ref-MGT20160616-ISD
            @w_monto_tope_isd               money,          -- valor tope para el cobros del ISD --ref-MGT20160616-ISD
            @w_ced_ruc_propietario          varchar(15),        -- cedula/ruc del propietario --ref-MGT20160616-ISD
            @w_mto_base_compr_int           money   ,       --REF-JCV20170601COMPEXTERIOR
            @w_valor_ori                    money   ,       -- REF-JCV20170601COMPEXTERIOR 
            @w_presencial                   char (1), --REF-20180402_COMPRAWEB  
            @w_medio                        char(3),  --REF-20180402_COMPRAWEB ,
            @w_id_adquirente                   int       --REF cubos autorización JLF 06122018     CAJ-CC:SGC00035932  
			,@w_referencia3_orig varchar(40) --REF cubos autorización JLF 06122018     CAJ-CC:SGC00035932  
			--,@v_causa_corr 					varchar(3) --ATM-CC-SGC00043061
			,@v_ind_rev_postmp				char(1) --ATM-CC-SGC00043061
			--<REF 19
			,@v_valor_req					money --REF 19> Valor requerido/solicitado orig
			,@v_iso_field42					int   -- Ref 21


    --==============================================================
    --select '-- Inicializacion de variable locales'
    --==============================================================
    select  
            @w_sp_name         = object_name(@@procid),
            @w_ssn             = 0,         
            @w_aba_banco       = 37,
            @w_rol             = 108,
            @w_srv             = 'LINEA1',          
            @w_sec_host        = @i_atm_secuencial,
            @w_num_lote        = '',
            --@w_cobrar_comision = 'S',         --QA SGC00042415   -- cuando se imp recibo con mas de una pagina desde la segunda pagina este valor debe ser N
            @w_tasa_conversion = 0,
            @w_cobro           = 'N',
            @w_referencia2     = @i_iso_field112,
            @i_comision        = isnull(@i_comision,0),
            @w_comision        = @i_comision,
            @i_cuenta_credito  = isnull(@i_cuenta_credito,'0000000000'),
            @i_autorizacion    = isnull(@i_autorizacion,'0'),
            @i_auth_reason	   = isnull(@i_auth_reason,''), --CAJ-CE-SGC00041850
			
            @w_periodicidad_cupo            = 'D',  -- pqm actualizacion del cupo de la cuenta
            @w_saldo_cupo                   = 0,    -- pqm actualizacion del cupo de la cuenta
            @w_saldo_cupo_cta               = 0,    -- pqm actualizacion del cupo de la cuenta 
            @w_cupo_compras_utilizado       = 0,    -- pqm actualizacion del cupo de la cuenta
            @w_cupo_compras_utilizado_cta   = 0,    -- pqm actualizacion del cupo de la cuenta
            @w_transacciones_usadas_cta     = 0,    -- pqm actualizacion del cupo de la cuenta 
            @w_transacciones_usadas         = 0,    -- pqm actualizacion del cupo de la cuenta
            @w_cupo_online                  = 0,    -- pqm actualizacion del cupo de la cuenta 
            @w_cupo_online_cta              = 0,    -- pqm actualizacion del cupo de la cuenta                      
            @w_referencia5                  = replicate(' ',11) + isnull(@i_iso_field42,''),
            @w_indicador_ganador='N',
            @w_monto_acum_isd               = 0,    -- Monto acumulado que se recibe desde Credimatic  -----ref-MGT20160616-ISD
            @w_monto_tota_isd               = 0,    -- Monto total para el calculo del ISD  --ref-MGT20160616-ISD
            @w_monto_tope_isd               = 0,    -- Monto tope para el cobre del ISD. ESTO DEBERIA ESTAR EN UN CATALOGO O TABLA DE PARAMETROS --ref-MGT20160616-ISD
            @w_monto_dife_isd               = 0     -- Valor sobre el que se cobrar el ISD  --ref-MGT20160616-ISD

    set @o_indicador_ganador=@w_indicador_ganador   

    

    --JLF obtener el bin desde el origen de la transaccion  CAJ-CC:SGC00035932  
    if @i_iso_field32 is not null    
    begin   
       if @i_origen = 'BANRE'
           select @w_id_adquirente   =  convert(int,right(@i_iso_field32,4))
       else  --visa
           select @w_id_adquirente   =  convert(int,@i_iso_field32)        
    end


    if @i_iso_field59 is null
       select @i_iso_field59 = 'NN'
    --JLF obtener el bin desde el origen de la transaccion

   
  /* if (@i_reentry='N') or (@i_reentry='S' and @i_reverso='S')
    begin    
		WAITFOR DELAY '00:00:11'
	end*/
     --==============================================================
    --  print Transacciones de retiro para diferentes medios
    --  16263   ACT TIEMPO AIRE PORTA AHO                          
    --  16263   ACT TIEMPO AIRE ALEGRO AHO                         
    --  16263   ACT TIEMPO AIRE MOVISTAR AHO                       
    --  16264   ACT TIEMPO AIRE PORTA CTE                          
    --  16264   ACT TIEMPO AIRE ALEGRO CTE                         
    --  16264   ACT TIEMPO AIRE MOVISTAR CTE                       
    --  16277   Compra por MDN CC                                  
    --  16280   Anulacion de compra por MDN CC                     
    --  16287   Compra por MDN AH                                  
    --  16290   Anulacion de compra por MDN AH                     
    --  16299   COMPRA PAGO MDN                                    
    --  16406   COMPRA AH VISA                                     
    --  16407   COMPRA CC VISA                                     
    --  16408   COMPRA PAGO VISA                                   
    --  16295   Compra PORTA AH                                    
    --  16296   Compra PORTA CC
    --==============================================================
    --if @i_trn not in (16263,16264,16287,16406,16277,16407,16299,16408,16290,16280,16300,16295,16296)
    --begin
    --   select @w_return = 171516
    --   goto lbl_error 
    --end
    ---JCV SGC00006826 MIGRACION CREDIMATIC
    /*if @i_trn in (16406,16407,16408)
    begin   
      --select @w_referencia5 = isnull(@i_cajero,'')+'902' +isnull(@i_iso_field42,'') +'000000'+isnull(@i_iso_field18,'')
       select @w_referencia5 = isnull(@i_cajero,'')+isnull(@i_iso_field22,'902') +isnull(@i_iso_field42,'') +'000000'+isnull(@i_iso_field18,'') --REF JVG-20140812-SGC00017088
    end*/
    
    
    --==============================================================
    --print '-- obtengo parametros generales'
    --==============================================================
    set @w_presencial ='S' --REF-20180402_COMPRAWEB  
    set @w_medio='POS'
    set @w_referencia = @i_iso_field25  
    --if substring(@i_iso_field22,1,2) in ('01','10') and  --CAJ-CE-SGC00042415
	if @i_dispositivo='90'   --CAJ-CE-SGC00042415
	begin 
        set @w_presencial ='N' 
        set @w_medio='INT' 
    end
    
    
    exec @w_return = sp_at_ptl_parametros 
         @i_trn            = @i_trn,
         @i_dispositivo    = @i_dispositivo, 
         @i_origen         = @i_origen, 
         --@i_reverso        = @i_reverso,
         @i_iso_field32    = @i_iso_field32,
         @i_tarjeta        = @i_tarjeta,
         @i_pais           = @i_pais,                   -- REF-JCV20170601COMPEXTERIOR
         @i_iso_field3     = @i_iso_field3, 
         @i_presencial     = @w_presencial,         --REF-20180402_COMPRAWEB
        
         @o_offline        = @w_offline           out,
         @o_fechap         = @w_fechap            out,
         @o_fecha_param    = @w_fecha_param       out,
         @o_indcob_isd_ret = @w_indcob_isd_ret    out,       
         @o_indcob_isd_cmp = @w_indcob_isd_cmp    out,
         @o_fi_banco       = @w_fi_banco          out,
         @o_ssn            = @w_ssn               out,
         -- Parametros de at_ruteo_tran
         @o_ttrn           = @w_ttrn              out,
         @o_proddeb        = @w_proddeb           out, 
         @o_prodcre        = @w_prodcre           out,
         @o_veri_cupo      = @w_veri_cupo         out,
         @o_tipo_cupo      = @w_tipo_cupo         out,
         @o_empresa        = @w_empresa           out,
         @o_veri_tarjeta   = @w_veri_tarjeta      out,
         @o_causa          = @w_causa             out,
         @o_gen_autoriza   = @w_gen_autoriza      out,
         @o_empresa_aut    = @w_empresa_aut       out,
         @o_canal          = @w_canal             out,
         @o_mensaje_atm    = @w_mensaje_atm       out,
         @o_signo_trn      = @w_signo_trn         out,
         @o_ind_comision   = @w_ind_comision      out,
         @o_promocion      = @w_promocion         out,
         @o_notificaSMS    = @w_notificaSMS       out,
         @o_retardo_SMS    = @w_retardo_SMS       out,
         @o_ind_isd        = @w_ind_isd           out,
         @o_moneda         = @w_moneda            out,       
         @o_aplcobis       = @w_aplcobis          out,
         @o_codcosto       = @w_codcosto          out,
         @o_dispositivo    = @w_dispositivo       out,
         @o_term           = @w_terminal          out,
         @o_srv            = @w_srv               out,  
         @o_porcentaje_isd = @w_porcentaje_isd    out,
         @o_aba_banco      = @w_aba_banco         out,
         @o_monto_tope_isd = @w_monto_tope_isd    out           -- ref-MGT20160616-ISD
         
         
    if @w_return <> 0
        goto lbl_error  

	--<REF 19
	select @v_valor_req = @i_valor 
	
	if @i_valor_auth > 0 and @i_valor_auth < @i_valor
		select @i_valor = @i_valor_auth
		
	--REF 19>

    --====================================================================================  
    -- Este segmento de codigo fue colocado al inicio del programa para impedir desde   
    -- el inicio la ejecucion de la transaccion si es que los cajeros estan en offline. 
    --====================================================================================
    if @w_offline = 'P' or convert(char(10),@i_fecha_concilia,101) != @w_fecha_param
       begin
          select @w_return = 160030
          goto lbl_error
       end
    -- REF-JCV20170601COMPEXTERIOR
    
    set @w_ind_comision = isnull(@w_ind_comision,'N')
    if @w_ind_comision='S' 
    begin  
        select @w_mto_base_compr_int=isnull(pa_money,0) from cobis..cl_parametro 
        where pa_producto='ATM' and pa_nemonico='VMCE'
        if @i_valor<=@w_mto_base_compr_int --si el monto de la trx es menor al monto base entonces no cobrar comision internacional.
            set @w_ind_comision='N'
    end
    --==============================================================
    --print '-- Validar la logtran'
    --==============================================================
    
    if @i_trn not in (16260,16261)
    begin
        exec @w_return = sp_at_ptl_valida_logtran
                         @i_lo_trn          = @i_trn
                        ,@i_lo_banco        = @w_aba_banco
                        ,@i_lo_sec_host     = @i_atm_secuencial
                        ,@i_lo_codtarjeta   = @i_cod_tarjeta
                        ,@i_lo_reverso      = @i_reverso
                        ,@i_lo_valor        = @i_valor
                        ,@i_cajero          = @i_cajero
                        ,@i_atm_secuencial  = @i_atm_secuencial
                        ,@i_cuenta_debito   = @i_cuenta_debito
                        ,@i_reentry         =@i_reentry  
						,@i_auth_reason     = @i_auth_reason	--CAJ-CE-SGC00041850
						,@i_autorizacion    = @i_autorizacion	--CAJ-CE-SGC00041850
						,@i_lo_fecha		= @i_fecha_trans	--CAJ-CE-SGC00042415
                        ,@o_log_valor       = @w_lvalor         out 
                        ,@o_log_comision    = @w_comision       out
                        ,@o_log_secuencial  = @w_secuencial     out
                        ,@o_code_return     = @o_codigo_error   out
						,@o_lo_referencia3 = @w_referencia3_orig out 
						,@o_ind_rev_postmp = @v_ind_rev_postmp out   --ATM-CC-SGC00043061 REVERSO DIAS POSTERIORES
						
						--@v_causa_corr	out  --ATM-CC-SGC00043061 REVERSO DIAS POSTERIORES
        
        if @o_codigo_error <> 0
            goto lbl_error      
    end   
	
	
	   
    -- CAJ-CC:SGC00035932 Se realiza un seteo del nombre de comercio (Campo 43) para las transacciones de reversos. POr casos especiales
	if @i_dispositivo='90' and @i_reverso='S' and  @w_referencia3_orig is not null and @i_iso_field43 <>@w_referencia3_orig begin
		set @i_iso_field43=@w_referencia3_orig
	end
	
  

    --==============================================================
    --print '-- Valida tarjeta, extrae información de la TD'
    --==============================================================
    
    if @w_veri_tarjeta = 'S'
    begin
    
        exec @w_return = sp_at_ptl_valida_tarjeta
             @i_operacion         = 'R',
             @i_cod_tarjeta       = @i_cod_tarjeta,
             @i_tarjeta           = @i_tarjeta,
             @i_cuenta_debito     = @i_cuenta_debito,
             @i_reentry           = @i_reentry,
             @i_fechap            = @w_fechap,
             @i_trn               = @i_trn,     ---envio de codigo de transaccion
             @i_canal             = @w_canal ,   ---envio de canal
			 @i_reverso			  = @i_reverso, --CAJ-CC-SGC00042296 REVERSOS TD BLOQUEADA
             @o_fecha_ult_mov_tar = @w_fecha_ult_mov_tar  out,
             @o_empresa_trj       = @w_empresa_trj        out,
             @o_ced_ruc           = @w_ced_ruc            out,
             @o_cliente           = @w_cliente            out,
             @o_num_tarjeta       = @w_tarjeta            out,
             --@o_sec_tarjeta       = @w_sec_tarjeta        out,     
             @o_tipo_tarjeta      = @w_tipo_tarjeta       out,
             @o_nombre_tarjeta    = @w_nombre_tarjeta     out,
             @o_codigo_propietario= @w_codigo_propietario out,
             @o_tarjeta_principal = @w_tarjeta_principal  out,
             
             --informacion de tm_emision
             @o_fecha_ult_mov_cta = @w_fecha_ult_mov_cta  out,
             @o_contador_bb       = @w_contador_bb        out,
             @o_contador_red      = @w_contador_red       out,
             
             @o_periodicidad_cupo          = @w_periodicidad_cupo           out, -- pqm actualizacion de cupo de la cuenta
             @o_saldo_cupo                 = @w_saldo_cupo                  out, -- pqm actualizacion de cupo de la cuenta
             @o_cupo_compras_utilizado     = @w_cupo_compras_utilizado      out, -- pqm actualizacion de cupo de la cuenta
             @o_transacciones_usadas       = @w_transacciones_usadas        out, -- pqm actualizacion de cupo de la cuenta
             @o_saldo_cupo_cta             = @w_saldo_cupo_cta              out, -- pqm actualizacion de cupo de la cuenta
             @o_cupo_compras_utilizado_cta = @w_cupo_compras_utilizado_cta  out, -- pqm actualizacion de cupo de la cuenta
             @o_transacciones_usadas_cta   = @w_transacciones_usadas_cta    out, -- pqm actualizacion de cupo de la cuenta
             @o_cupo_online                = @w_cupo_online                 out, -- pqm actualizacion del cupo de la cuenta 
             @o_cupo_online_cta            = @w_cupo_online_cta             out  -- pqm actualizacion del cupo de la cuenta
             
        if @w_return <> 0
            goto lbl_error
			
			
			
		--<REF 20

		-- ISD Transacciones de retiro del exterior --ref-MGT20160616-ISD
    
		select @w_valor_base_ids = @i_valor                                 
		
		if @i_trn in (16406,16407) and  ( @i_pais != 'EC') 
		begin
			if @i_iso_field108 is null or @i_iso_field109 is null
			begin

				select @w_nume_docum_isd = @w_ced_ruc --obtenido del maestro de tarjetas
			  
				exec @w_return = pa_mdp_cmonto_acumisd
					@e_mis = @w_cliente,
					@e_identificacion = @w_ced_ruc,
					@e_fecha_trans = @i_fecha_trans,
					@s_monto_acum_isd = @w_monto_acum_isd out,
					@s_tipo_id = @w_tipo_docum_isd out
					
					
				if @w_return <> 0
				begin
					goto lbl_error	
				end
				
				
				
			end  
			else 
			begin 
			  
				select @w_monto_acum_isd =  (convert(money,@i_iso_field108)) / 100,
				   @w_tipo_docum_isd =  substring(@i_iso_field109,1,2),
				   @w_nume_docum_isd =  substring(@i_iso_field109,3,len(@i_iso_field109)-2)
			
			
			end
			   
				   
				   
			
			--REF-JCV20170601COMPEXTERIOR esto se lo realiza debido a que para los escenarios de reverso 
			--el valor de acumulador ya viene incrementado y se necesita calcular de manera correcta el ISD
			if @i_reverso='S' begin
				set @w_monto_acum_isd=@w_monto_acum_isd-@w_valor_base_ids  
			end 
				
			if @w_monto_acum_isd >= @w_monto_tope_isd
			   select @w_monto_dife_isd = @i_valor      
			else    
				begin
					set  @w_monto_tota_isd =  @w_monto_acum_isd + @i_valor
					set  @w_monto_dife_isd =  @w_monto_tota_isd - @w_monto_tope_isd
							   
					if @w_monto_dife_isd <= 0
							select @w_monto_dife_isd = 0
				end 
				
			select  @w_valor_base_ids =  @w_monto_dife_isd
			
			--REF-JCV20170601COMPEXTERIOR 
			if @w_valor_base_ids = 0
			begin
				select @w_valor_ori = @i_valor
			end
			else
			begin
				select @w_valor_ori = @w_monto_dife_isd
			end
					
			select @w_valor_referencia2 = convert(varchar,@w_valor_ori)
		end
		
		-- ISD Transacciones de retiro del exterior --ref-MGT20160616-ISD
		   
		--==============================================================
		--print '-- Cobro de valor ISD'
		--==============================================================
		exec sp_at_ptl_calcula_isd --@w_return 
			  @i_ind_isd           = @w_ind_isd
			 ,@i_pais              = @i_pais
			 ,@i_reverso           = @i_reverso
			 ,@i_trn               = @i_trn
			 ,@i_valor_log         = @w_lvalor
			 ,@i_valor             = @i_valor                           --ref-MGT20160607-ISD        
			 ,@i_base_valor_isd   = @w_valor_base_ids                       --REF-JCV20170601COMPEXTERIOR
			 
			 ,@i_porcentaje_isd    = @w_porcentaje_isd
			 ,@i_indcob_isd_ret    = @w_indcob_isd_ret
			 ,@i_indcob_isd_cmp    = @w_indcob_isd_cmp
			 ,@o_valor_isd         = @w_valor_isd       out



		--REF 20>
			
			
        -- ISD Transacciones de retiro del exterior --ref-MGT20160616-ISD  - Inicio
         
         if @i_trn in (16406,16407) and  ( @i_pais != 'EC') 
            begin
                select @w_ced_ruc_propietario = @w_ced_ruc                     
                
                if @w_tarjeta_principal <> 0    --- Cuando es adicional se obtiene la ID del propietario
                   begin
                        select @w_ced_ruc_propietario = ta_ced_ruc 
                          from tm_tarjeta where ta_tarjeta = @w_tarjeta_principal
                        if @@rowcount != 1
                            begin
                              select @w_return = 160000
                              goto lbl_error
                            end  
                   end         
                if @w_nume_docum_isd <> @w_ced_ruc_propietario
                   begin
                      select @w_return = 168010
                      goto lbl_error    
                   end   
            end
        -- ISD Transacciones de retiro del exterior --ref-MGT20160616-ISD  - Fin            
    end --end verificacion tarjeta 
    
    --==============================================================
    -- Calcular el nuevo valor del los cupo
    --==============================================================
        
    exec @w_return = sp_at_ptl_valida_cupo 
                    @i_trn                      = @i_trn,
                    @i_ttrn                     = @w_ttrn,
                    @i_fecha_trans              = @i_fecha_trans,
                    @i_fecha_ult_mov            = @w_fecha_ult_mov_tar,
                    @i_fecha_ult_mov_cta        = @w_fecha_ult_mov_cta,
                    @i_valor                    = @i_valor,
                    @i_periodicidad_cupo        = @w_periodicidad_cupo, 
                    @i_veri_cupo                = @w_veri_cupo, 
                    @i_tipo_cupo                = @w_tipo_cupo,
                    @i_reverso                  = @i_reverso,
                    
                    @i_cupo_online              = @w_cupo_online,
                    @i_cupo_online_cta          = @w_cupo_online_cta,
                    @i_reentry                  = @i_reentry,
                    
                    -- cupo de la tarjeta/cuenta input
                    @i_saldo_cupo               = @w_saldo_cupo,
                    @i_cupo_compras_utilizado   = @w_cupo_compras_utilizado,
                    @i_transacciones_usadas     = @w_transacciones_usadas,
                    @i_saldo_cupo_cta             = @w_saldo_cupo_cta ,
                    @i_cupo_compras_utilizado_cta = @w_cupo_compras_utilizado_cta,
                    @i_transacciones_usadas_cta   = @w_transacciones_usadas_cta, 
                    
                    -- cupo de la tarjeta/cuenta output
                    @o_saldo_cupo                   = @w_saldo_cupo                 out,
                    @o_cupo_compras_utilizado       = @w_cupo_compras_utilizado     out,
                    @o_transacciones_usadas         = @w_transacciones_usadas       out,
                    @o_saldo_cupo_cta               = @w_saldo_cupo_cta             out,
                    @o_cupo_compras_utilizado_cta   = @w_cupo_compras_utilizado_cta out,
                    @o_transacciones_usadas_cta     = @w_transacciones_usadas_cta   out
    
    if @@error != 0 or @w_return != 0 
    begin
        set @w_return = 168013
        goto lbl_error
    end 
    

    
    --==============================================================
    -- Si origen es MEDIANET 
    --==============================================================
    if @i_origen = 'MDNET'
    begin 
        set @w_num_lote     = @i_iso_field114       -- aqui ingresar el numero de lote toca definir en que parametro postilio pasa el n. lote
        ---REF JVG-20140812-SGC00017088
        if @i_iso_field18 is null and @i_trn in (16290,16280,16300) begin ---solo se ingresa para cuando sean anulaciones MDNET y no provenga el codigo del campo 18 (merchant type)
                
                SELECT  @i_iso_field18=substring (isnull(lo_referencia5,'') ,33,4)
                FROM at_logtran
                WHERE lo_codtarjeta       = @i_cod_tarjeta
                and lo_banco            = @w_aba_banco
                and lo_sec_host         = @w_sec_host
                and lo_trn              in (16287,16277,16299)   ---buscar trx original de compra de cta:  ah o cte o virtual
                and lo_atm              = @i_cajero  
                and lo_atm_secuencial   = @i_atm_secuencial 
                
                if @i_iso_field18 is null begin
                        SELECT  @i_iso_field18=substring (isnull(hl_referencia5,'') ,33,4)
                        FROM at_his_logtran A 
                        WHERE A.hl_codtarjeta       = @i_cod_tarjeta
                        and A.hl_fecha              <=@i_fecha_trans 
                        and A.hl_sec_host           =@w_sec_host
                        and A.hl_trn                in (16287,16277,16299)      ---buscar trx original de compra de cta:  ah o cte o virtual
                        and A.hl_banco              =@w_aba_banco
                        and A.hl_atm                = @i_cajero  
                        and A.hl_cuenta1            = @i_cuenta_debito
                    
                    
                end
        end
    end
    
    --==============================================================
    --print '-- Setea variable Exonera costo'
    --==============================================================    
    if @i_comision > 0 and @w_ind_exon <> 'N'
        select @w_ind_exon = 'S'
    else
        select @w_ind_exon = 'N'

--ESTE PROCEDIMIENTO ES EL QUE DEBE DEVOLVER LA COMISION    
    --==============================================================
    --print '-- Genera costo'
    --==============================================================    

    if @w_ind_comision = 'S' 
    begin
         exec @w_return        = sp_at_genera_costo_trn
             @s_date          = @w_fechap
            ,@s_ofi           = @i_oficina
            ,@i_moneda        = @w_moneda
            ,@t_corr          = @i_reverso
            ,@t_rty           = @i_reentry
            ,@i_tarjeta       = @w_tarjeta
            ,@i_producto      = @w_proddeb
            ,@i_cta           = @i_cuenta_debito
            ,@i_empresa_trj   = @w_empresa_trj
            ,@i_trn           = @i_trn
            ,@i_fecha_ult_trn = @w_fecha_ult_mov_cta
            ,@i_contador_bb   = @w_contador_bb
            ,@i_contador_red  = @w_contador_red
            ,@i_cod_canal     = @w_canal
            ,@i_costo         = @w_comision
            ,@i_causa         = @w_causa
            ,@i_codcost       = @w_codcosto
            ,@o_retorno       = @w_ind_exon     out
            ,@o_contador_bb   = @w_contador_bb  out
            ,@o_contador_red  = @w_contador_red out
            ,@o_costo         = @w_comision     out
            ,@o_trn_cob       = @w_trn_cob      out
            ,@o_causal_cob    = @w_causal_cob   out
        
        if @w_return != 0
           goto lbl_error

        /*  Reverso Parcial */
        if @w_lvalor != @i_valor and @i_reverso = 'S'
           select @w_comision = 0
    end

    /* Encero el contador de transacciones por nuevo mes */
    if @w_ind_comision = 'N' and (datediff(mm,@w_fecha_ult_mov,@w_fechap) > 0)
       select @w_contador_bb  = 0
             ,@w_contador_red = 0
             
    set @w_comision = isnull(@w_comision,0)

    --==============================================================
    --print '-- Transaccion Cobis'
    --==============================================================                            
    select @w_rpc = case @w_proddeb when 'AHO' then 'sp_at_compra_ah'
                                    when 'CTE' then 'sp_at_compra_cc' 
                                    when 'PAG' then 'sp_at_compra_vr'                        
                     end
    ---REF JVG-20140812-SGC00017088
    select @w_valor_debito1=0,@w_valor_debito2=0
    if @i_iso_field18='5541' and @i_pais ='EC'  --si es gasolinera en ecuador
    begin
        if @i_origen = 'MDNET'  ---si origen es medianet 
        begin

			select @v_iso_field42= convert(int,isnull(@i_iso_field42,'0')) -- Ref 21
            if exists (select 1 from db_tarjeta_bb..tc_estcomerc_bb where es_codigo=@v_iso_field42 and es_estado ='A' and es_giro_visa='5541' and  es_mark_afil_visa='S' and es_mark_afil_elect='S')  -- Ref 21
			begin
			   			   
			   select  @w_monto_graba_iva=0, @w_monto_no_graba_iva=0
                if @i_iso_field119 is not null 
                begin
                    select   @w_monto_graba_iva=isnull(convert(money, 
							 substring((substring(@i_iso_field119,1,12)),1,10)+'.'+
                             substring((substring(@i_iso_field119,1,12)),11,2)),0)
							 
                    select   @w_monto_no_graba_iva=isnull(convert(money, 
							 substring((substring(@i_iso_field119,13,12)),1,10)+'.'+
                             substring((substring(@i_iso_field119,13,12)),11,2)),0)
                    
                    if @i_iso_field120 is not null 
                    begin
                        set @w_len_campo=len (rtrim(@i_iso_field120))
                        set @w_iterador=2

                        while @w_iterador<@w_len_campo
                        begin
                            select @w_tipo_campo=substring(@i_iso_field120,@w_iterador,1)
                            
                            if ((@w_tipo_campo='1') or (@w_tipo_campo='2') or (@w_tipo_campo= '3') or (@w_tipo_campo='4') or (@w_tipo_campo='5'))  
                            begin
                                select  @w_valorcampo= convert(money, substring((substring(@i_iso_field120,@w_iterador+1,12)),1,10)+'.'+
                                                                      substring((substring(@i_iso_field120,@w_iterador+1,12)),11,2))
                            end
                            if @w_tipo_campo='1' 
                             set @w_valor_iva= @w_valorcampo
                            else if @w_tipo_campo='2' 
                             set @w_valor_servicio= @w_valorcampo
                            else if @w_tipo_campo='3' 
                             set @w_valor_propina= @w_valorcampo
                            else if @w_tipo_campo='4' 
                             set @w_valor_interes= @w_valorcampo
                            else if @w_tipo_campo='5' 
                             set @w_valor_monto_fijo= @w_valorcampo

                            set @w_iterador=@w_iterador+13
                        end ---fin del while                
                        select  @w_valor_iva=isnull(@w_valor_iva,0)
                                ,@w_valor_servicio=isnull(@w_valor_servicio,0)
                                ,@w_valor_propina=isnull(@w_valor_propina,0)
                                ,@w_valor_interes=isnull(@w_valor_interes,0)
                                ,@w_valor_monto_fijo=isnull(@w_valor_monto_fijo,0)
                        
                        --select @w_valor_debito1=@w_monto_graba_iva+@w_valor_iva+@w_valor_servicio
                        select @w_valor_debito2=@w_valor_monto_fijo --@i_valor-@w_valor_debito1---@w_valor_monto_fijo
                        select @w_valor_debito1=@i_valor-@w_valor_debito2
                        select @w_referencia4='IVA'+convert(varchar(12),@w_valor_iva)+'SRV'+convert(varchar(12),@w_valor_servicio)+'PRO'+convert(varchar(12),@w_valor_propina)+ 
                                              'INT'+convert(varchar(12),@w_valor_interes)+'MTO'+convert(varchar(12),@w_valor_monto_fijo)
                        
                        
                        select @w_valor_referencia2='DEBIT1:'+convert(varchar(12),@w_valor_debito1)
                    end--fin de validacion del campo 120                        
                end--fin de validacion del campo 119
            end 
            else 
			begin
                
				exec cob_pagos..sp_verif_genera_costo  --se debe buscar en una estructura del person para trx desde mdnet bancos socios
				   @s_date     = @w_fechap
				  ,@i_mon      = 1
				  ,@i_rubro    = 'CGBK'
				  ,@i_servicio = 'POSE'
				  ,@i_canal    = 'ATM'
				  ,@o_costo    =@w_valor_comision_medianet_gas out

				if @w_valor_comision_medianet_gas is null
				begin
						set @w_return = 160111
						goto lbl_error
				end
				select @w_valor_debito2=@w_valor_comision_medianet_gas
				select @w_valor_debito1=@i_valor-@w_valor_debito2
				
				select @w_valor_referencia2='DEBIT1:'+convert(varchar(12),@w_valor_debito1)
				
            end --fin else de comercio
        end--fin de validacion de medianet
        else begin               --si origen es credimatic
			
			if convert(bigint,isnull(@i_iso_field42,'0')) <= (select max(es_codigo) from db_tarjeta_bb..tc_estcomerc_bb where es_estado ='A' and es_giro_visa='5541' and  es_mark_afil_visa='S' and es_mark_afil_elect='S')
			begin
				--buscar datos en modulo de personalizacion (PERSON)				
				select @v_iso_field42= convert(int,isnull(@i_iso_field42,'0')) -- Ref 21
				if exists (select 1 from db_tarjeta_bb..tc_estcomerc_bb where es_codigo=@v_iso_field42 and es_estado ='A' and es_giro_visa='5541' and  es_mark_afil_visa='S' and es_mark_afil_elect='S')  -- Ref 21
				begin
			   
				   --<REF 20
				   exec cob_pagos..sp_verif_genera_costo  
					   @s_date     = @w_fechap
					  ,@i_mon      = 1
					  ,@i_rubro    = 'CGBP' -- Se debe crear nuevo rubro ComisionGasolineraBancoPropio
					  ,@i_servicio = 'POSE'
					  ,@i_canal    = 'ATM'
					  ,@o_costo    =@w_valor_comision_medianet_gas out

					if @w_valor_comision_medianet_gas is null
					begin
							set @w_return = 160111
							goto lbl_error
					end
					select @w_valor_debito2=@w_valor_comision_medianet_gas
					select @w_valor_debito1=@i_valor-@w_valor_debito2
					
					select @w_valor_referencia2='DEBIT1:'+convert(varchar(12),@w_valor_debito1)
					--REF 20>
				end
				else
				begin
					exec cob_pagos..sp_verif_genera_costo
					   @s_date     = @w_fechap
					  ,@i_mon      = 1
					  ,@i_rubro    = 'CGAS'
					  ,@i_servicio = 'POSE'
					  ,@i_canal    = 'ATM'
					  ,@o_costo    =@w_valor_comision_credim_gas out

					if @w_valor_comision_credim_gas is null
					begin
							set @w_return = 160111
							goto lbl_error
					end
					select @w_valor_debito1=@i_valor-@w_valor_comision_credim_gas
					select @w_valor_debito2=@w_valor_comision_credim_gas
					select @w_valor_referencia2='DEBIT1:'+convert(varchar(12),@w_valor_debito1)
				end
			end --fin validacion bigint
			else
			begin
				exec cob_pagos..sp_verif_genera_costo
				   @s_date     = @w_fechap
				  ,@i_mon      = 1
				  ,@i_rubro    = 'CGAS'
				  ,@i_servicio = 'POSE'
				  ,@i_canal    = 'ATM'
				  ,@o_costo    =@w_valor_comision_credim_gas out

				if @w_valor_comision_credim_gas is null
				begin
						set @w_return = 160111
						goto lbl_error
				end
				select @w_valor_debito1=@i_valor-@w_valor_comision_credim_gas
				select @w_valor_debito2=@w_valor_comision_credim_gas
				select @w_valor_referencia2='DEBIT1:'+convert(varchar(12),@w_valor_debito1)
			end
        end --fin else origen credim/cardtch
    end
    --COMPRAS INTERNACIONALES REF 20170601JCV_COMPOFFL
    if @i_origen in ('MDNET','VISA') begin
        select @w_referencia5 = isnull(@i_cajero,'')+isnull(@i_iso_field22,'000') +isnull(@i_iso_field42,'') +'000000'+isnull(@i_iso_field18,'') 
    end
    
	--ATM-CC-SGC00043061 >> REVERSO DIAS POSTERIORES
	if @v_ind_rev_postmp != null and @v_ind_rev_postmp = 'S' begin --existe reverso postemp
		set @w_causa = '952' --@v_causa_corr
	
		select @w_ind_isd = 'N', @w_valor_isd =0, --reverso postemp no reversa isd
				@w_ind_comision='N', @w_comision=0 --reverso postemp no reversa comision 
		
		--Transformar ttrn a NC 
		if @i_trn in (16406, 16287)  --AHO --CAJ-CE-SGC00044330 16287
			set @w_ttrn = 4253					
		if @i_trn in (16407, 16277)  --CTE  --CAJ-CE-SGC00044330 16277
			set @w_ttrn = 3048
		--VIR no aplica a reversos web 
		/*if @i_trn = 16408  
			set @w_ttrn = 120003*/ 
			
	end
    --ATM-CC-SGC00043061 <<
    
    begin tran RETIRO   

    exec @w_return = @w_rpc
            @s_lsrv             = null,                 --varchar(30)
            @s_sesn             = null,                 --int
            @s_rol              = @w_rol,
            @s_ssn              = @w_ssn,               --int         = null
            @s_srv              = @w_srv,               --varchar(30) = null
            @s_user             = @i_cajero,            --varchar(30) = null
            @s_term             = @w_terminal,          --varchar(10) = null
            @s_date             = @w_fechap,            --datetime    = null
            @s_ofi              = @i_oficina,           --tinyint     = 1
            @t_corr             = @i_reverso,           --char(1)     = 'N'
            @t_ssn_corr         = @i_atm_secuencial,    --int         = null
            @t_rty              = @i_reentry,           --char(1)     = 'N'
            @t_trn              = @i_trn,               --int         = null
            @t_ttrn             = @w_ttrn,              --smallint    = null
            @i_trn              = @w_ttrn,              --int         = null
            @i_empresa_aut      = @w_empresa_aut,       --smallint    = null
            @i_cajero           = @i_cajero,            --varchar(8)  = null
            @i_fecha_real       = @i_fecha_real,        --datetime    = null
            @i_fecha_trans      = @i_fecha_trans,       --datetime    = null
            @i_autorizacion     = @i_autorizacion,      --varchar(6)  = null
            @i_referencia       = null,                 --varchar(40) = null
            @i_referencia3     = @i_iso_field43 ,   -- REF-JCV20170601COMPEXTERIOR 
            @i_referencia4      = null,                 --varchar(40) = null
            @i_referencia5      =  @w_referencia5   ,   --varchar(40) = null  REF-JCV20170601COMPEXTERIOR 
            @i_ced_ruc          = @w_ced_ruc,           -- varchar(13)= null
            @i_num_lote         = @w_num_lote,          --varchar(7)  = null
            @i_dispositivo      = @w_dispositivo,       --tinyint     = null
            @i_cod_banco        = @w_aba_banco,         --int         = null
            @i_sec_host         = @w_sec_host,          --int         = null
            @i_tarjeta          = @w_tarjeta,           --char(24)    = null
            @i_prodeb           = @w_proddeb,           --descripcion = null
            @i_cta              = @i_cuenta_debito,     --cuenta      = null
            @i_val              = @i_valor,             --money       = null
            @i_mon              = @w_moneda,            --tinyint     = null
            @i_causa            = @w_causa,             --char(3)
            @i_gen_autoriza     = @w_gen_autoriza,      --char(1)     = 'N'
            @i_valor_isd        = @w_valor_isd,         --money       = 0      -- jhpe
            @i_pais             = @i_pais,              --varchar(3)  = 'EC'   -- jhpe
            @i_localidad        = @w_aba_banco,         -- int        = 0      -- jhpe
            @i_sec_tarjeta      = @i_cod_tarjeta,       -- int
            @i_canal            = @w_canal,             -- char(3)
            @i_comision         = @w_comision,          -- money    --REF: JVG-20170629 COMPRAS INTERNACIONALES 
            @i_codigo_comercio  = @i_iso_field18,       --varchar =null ---REF JVG-20140812-SGC00017088 Deflactacion Comision Gasolinera
            @i_valor_debito1    = @w_valor_debito1,     --money =null   ---REF JVG-20140812-SGC00017088 Deflactacion Comision Gasolinera
            @i_valor_debito2    = @w_valor_debito2,     --money =null   ---REF JVG-20140812-SGC00017088 Deflactacion Comision Gasolinera
            @i_trn_cob          = @w_trn_cob,           --REF: JVG-20170629 COMPRAS INTERNACIONALES 
            @i_causal_cob       = @w_causal_cob,        --REF: JVG-20170629 COMPRAS INTERNACIONALES 
            @i_aplcobis         = @w_aplcobis ,         --REF: JVG-20170629 COMPRAS INTERNACIONALES 
            @i_medio            = @w_medio,             --REF-20180402_COMPRAWEB  
			@i_field_109		= @i_iso_field109,		--ref-20200908-IVASERDIG
            @o_codigo_error     = @o_codigo_error       out,    --int         = null out
            @o_salcondb         = @o_saldo_contable     out,    --money       = null out
            @o_saldisdb         = @o_saldo_disponible   out,    --money       = null out
            @o_saldiscr         = @o_saldiscr           out,    --money       = null out
            @o_salconcr         = @w_salconcr           out,    --money       = null out
            @o_autorizacion     = @o_autorizacion       out,    --varchar(6)  = null out
            @o_mensaje          = @o_mensaje            out,    --varchar(255)  = '' out -- REF:10
            @o_nombre           = @o_nombre             out     --varchar(3)    = '' out -- Ref.12
        
        
		--print "o_mensaje: '%1!'  o_nombre '%2!'.", @o_mensaje, @o_nombre
		
		
        if (@o_codigo_error <> 0 or @w_return <> 0)
        begin
            rollback transaction
            if @o_codigo_error < 1
                select @o_codigo_error = 160111
            
            select  @o_saldo_contable   = 0,
                    @o_saldo_disponible = 0,
                    @o_saldiscr         = 0,
                    @o_autorizacion     = ''
            
            --if @o_codigo_error < 1
            --    select @o_codigo_error = @w_return

            --==============================================================
            --print '-- MULTAS'
            --==============================================================                            
            exec sp_at_multa_trns --@w_return      = 
                 @s_ssn         = @w_ssn
                ,@s_lsrv         = ' ' 
                ,@s_sesn         = 0
                ,@s_srv         = @w_srv
                ,@s_user        = @i_cajero
                ,@s_term        = @w_terminal
                ,@s_date        = @w_fechap
                ,@s_ofi         = @i_oficina
                ,@s_rol         = @w_rol
                ,@t_corr        = @i_reverso
                ,@t_trn         = @i_trn
                ,@t_ttrn        = @w_ttrn                             --Ya no existe el codigo de ON2 420-520-424-524
                ,@t_rty         = @i_reentry
                ,@t_ssn_corr    = @i_atm_secuencial
                ,@i_aplcobis    = @w_aplcobis
                ,@i_val         = @i_valor
                ,@i_empresa_trj = @w_empresa_trj
                ,@i_prodeb      = @w_proddeb
                ,@i_cta         = @i_cuenta_debito
                ,@i_error       = @o_codigo_error
                ,@i_mon         = @w_moneda
                ,@i_fecha_trans = @i_fecha_trans
                ,@i_dispositivo = @w_dispositivo
                ,@i_cajero      = @i_cajero
                ,@i_tarjeta     = @w_tarjeta
                ,@i_pais        = @i_pais
                                        
    
          goto lbl_error
        end

        --==============================================================
        --print '-- AUTORIZACION'
        --==============================================================            
        if @w_gen_autoriza in ('I','A')
        begin
        
            if substring(@w_referencia2,1,12) = '005006060700' --SUPERMAXI
                select @w_empresa_aut = 42
                
            if @i_trn = 16280 or @i_trn = 16290
                select @i_fecha_trans = dateadd(ss,1,@i_fecha_trans)
            
            exec @w_return = sp_at_inserta_autorizacion
                 @s_ssn          = @w_ssn
                ,@s_srv          = @w_srv
                ,@s_term         = @w_terminal
                ,@s_date         = @w_fechap
                ,@s_ofi          = @i_oficina
                ,@t_corr         = @i_reverso
                ,@t_ssn_corr     = @i_atm_secuencial
                ,@t_trn          = @i_trn
                ,@t_ttrn         = @w_ttrn                  -- Con el nuevo SWITCH POSTILIO ya no se maneja los codigos ON2 420,424,520,524
                ,@t_rty          = @i_reentry
                ,@i_empresa_aut  = @w_empresa_aut
                ,@i_cajero       = @i_cajero
                ,@i_fecha_real   = @i_fecha_real
                ,@i_fecha_trans  = @i_fecha_trans
                ,@i_autorizacion = @i_autorizacion
                --,@i_referencia   = @i_referencia  
                ,@i_num_lote     = @w_num_lote
                ,@i_dispositivo  = @w_dispositivo
                ,@i_cod_banco    = @w_aba_banco
                ,@i_sec_host     = @w_sec_host
                ,@i_tarjeta      = @i_tarjeta       -- Formato Mascar 
                ,@i_ced_ruc      = @w_ced_ruc
                ,@i_tipocta      = @w_proddeb
                ,@i_cta          = @i_cuenta_debito
                ,@i_val          = @i_valor
                ,@i_mon          = @w_moneda
                ,@i_estado       = @w_gen_autoriza
                ,@i_signo        = @w_signo_trn
                ,@i_codigo_tarjeta  = @i_cod_tarjeta
                ,@i_codigo_cliente  = @w_cliente
                ,@i_lo_giro_comercio =@i_iso_field18  ---cambio COMPRASOFFLINE Y CONTROLSTANDIN     -- REF-JCV20170601COMPEXTERIOR
                ,@i_lo_offline         = @w_offline
                ,@o_autorizacion    = @o_autorizacion out
            
            --JCVELIZ Cambio Solicitado por QADBA para control validaciones : 03/Julio/2014     
            if @w_return <> 0
            begin
               rollback transaction
               goto lbl_error
            end
                
            --==============================================================
            --print '-- COMPROBANTE'
            --==============================================================                            
            if @w_ind_isd = 'S' and @i_pais != 'EC' and @i_valor > 0  --REF-AMMO20190326_COMPRAWEB_E02
            begin
                if ((@i_trn in (16403,16404) and @w_indcob_isd_ret = 'S') or (@i_trn in (16406,16407) and @w_indcob_isd_cmp = 'S'))
                begin           
								
                   exec @w_return = cob_atm..sp_at_comprobante_isd
                         @i_trn                 = @i_trn,                   
                         @i_tarjeta             = @w_tarjeta,           
                         @i_cliente             = @w_cliente,           
                         @i_codtarjeta          = @i_cod_tarjeta,  -- REF:60     
                         @i_tarj_propietario    = @w_codigo_propietario,
                         @i_tarj_principal      = @w_tarjeta_principal, 
                         @i_cajero              = @i_cajero,            
                         @i_banco               = @w_aba_banco,         
                         @i_cuenta	            = @i_cuenta_debito,     
                         @i_secuencia_atm       = @i_atm_secuencial,    
                         @i_secuencia           = @w_secuencial,        
                         @i_autorizacion        = @o_autorizacion,      
                         @i_fecha_contable      = @i_fecha_concilia,  -- REF:62  
                         @i_fecha_transaccion   = @i_fecha_trans,       
                         @i_valor               = @i_valor,             
                         @i_nombre_beneficiario = @i_iso_field43,   -- REFERENCIA3    
                         @i_pais                = @i_pais,              
                         @i_reverso             = @i_reverso,           
                         @i_valor_cobro_isd     = @w_valor_base_ids,   --ref-MGT20160616-ISD 
                         @e_motivo_econ         = @i_iso_field18  -- ref 21 GPR-14882

                end
            end

            if @w_return != 0
            begin
               rollback tran
      
               select @o_codigo_error     = @w_return
                     ,@o_saldo_contable   = 0
                     ,@o_saldo_disponible = 0
                     ,@o_saldiscr         = 0
                     ,@o_autorizacion     = ''
                                  
                if @w_aplcobis = 'S'
                begin
                    exec cobis..sp_cerror
                          @t_debug = 'N'
                         ,@t_from  = @w_sp_name
                         ,@i_num   = @w_return
                    
                    set @o_codigo_error = 160111
                end
                goto lbl_error           
            end
			
			--<REF 20
			if @i_pais != 'EC' and @i_valor > 0 and @i_trn in (16406,16407) and @w_indcob_isd_cmp = 'S' and (@i_iso_field108 is null or @i_iso_field109 is null)
            begin 				
				--print 'tipo id %1!', @w_tipo_docum_isd
				
				exec @w_return = cob_atm..pa_mdp_adebit_acumisd
					@e_mis = @w_cliente
					,@e_identificacion = @w_nume_docum_isd	
					,@e_fecha_trans	= @i_fecha_trans	
					,@e_monto = @i_valor			
					,@e_tipo_id = @w_tipo_docum_isd		
					,@e_offline = @w_offline			
					,@e_reverso	= @i_reverso		
					
				if @w_return != 0
				begin
					rollback tran
					goto lbl_error 	
				end
					
			end
			--REF 20> 
			
        end

        --==============================================================
        --print '-- GRABO EN TABLA DE LOGGER at_logtran'
        --==============================================================            

--      JLF ref AUTORIZACION CUBOS  07/06/2018  CAJ-CC:SGC00035932  
        if @i_origen = 'VISA'  ---si origen es medianet 
        begin
            if @w_presencial ='N'  and @i_iso_field60ECI is not null 
                select @w_referencia4 = @w_referencia4 + '|'+ @i_iso_field60ECI + '|'

            if @i_pais in ('US','CA')
                select @w_referencia4 = @w_referencia4 +  @i_iso_field59 + '|'  --codigo provincia, solo aplica para US y CA
        end
        		
        if @w_ind_exon != 'N'
            select @w_cobro = isnull(@w_ind_exon,'N')
        		
		
         exec sp_at_ptl_logueotran --@w_return = 
                @i_lo_reverso         = @i_reverso
               ,@i_lo_atm             = @i_cajero              
               ,@i_lo_trn             = @i_trn
               ,@i_lo_ttrn            = @w_ttrn
               ,@i_lo_sec_host        = @w_sec_host
               ,@i_lo_atm_secuencial  = @i_atm_secuencial   -- Secuencia de ATM POSTILIO
               ,@i_lo_vsecuencial     = @w_ssn              -- Secuecnial COBIS
               ,@i_lo_tarjeta         = @i_tarjeta          -- Graba tarjeta con Mascara
               ,@i_lo_fecha           = @i_fecha_trans
               ,@i_lo_valor           = @i_valor			--valor autorizado 
               ,@i_lo_cuenta1         = @i_cuenta_debito
               ,@i_lo_cuenta2         = @i_cuenta_credito              
               ,@i_lo_banco           = @w_aba_banco
               ,@i_lo_offline         = @w_offline
               ,@i_lo_uso_cajero      = @w_cobro 
               ,@i_lo_oficina         = @i_oficina
               ,@i_lo_tasa_conver     = @w_tasa_conversion
               ,@i_lo_moneda          = @w_moneda
               ,@i_lo_valor_reverso   = 0
               ,@i_lo_fecha_concilia  = @i_fecha_contable
               ,@i_lo_dispositivo     = @w_dispositivo
               ,@i_lo_reentry         = @i_reentry
               ,@i_lo_empresa         = @i_empresa
               ,@i_lo_referencia      = @w_referencia ---null  --REF-20180402_COMPRAWEB  
               ,@i_lo_referencia2     = @w_valor_referencia2 --null
               ,@i_lo_referencia3     = @i_iso_field43
               ,@i_lo_referencia4     = @w_referencia4       --JLF referenciaa 4 graba ECI + field59 CAJ-CC:SGC00035932
               ,@i_lo_referencia5     = @w_referencia5             
               ,@i_lo_pais            = @i_pais
               ,@i_lo_comision        = @w_comision     
               ,@i_lo_codtarjeta      = @i_cod_tarjeta
               ,@i_lo_codcliente      = @w_cliente
               ,@i_lo_valor_isd       = @w_valor_isd 
               ,@i_lo_autorizacion    = @o_autorizacion
               ,@i_lo_solicitud_recibo= @i_solicitud_recibo
               ,@i_monto_fuente       = @i_monto_fuente     -- REF-JCV20170601COMPEXTERIOR
               ,@i_moneda_fuente      = @i_moneda_fuente    -- REF-JCV20170601COMPEXTERIOR
               ,@i_presencial         = @w_presencial       --REF-20180402_COMPRAWEB  
               ,@i_id_adquirente         = @w_id_adquirente       -- REF JLF 20180619 cubos, bin  CAJ-CC:SGC00035932
     			--<REF 19 
	           ,@i_valor_req			= @v_valor_req --Monto original requerido/solicitado
			   --REF 19>
               ,@o_code_return        = @o_codigo_error out

            if @o_codigo_error <> 0
            begin
               rollback transaction
               goto lbl_error
            end

        --==============================================================
        --print '-- Valida tarjeta, actualiza información de la TD'
        --==============================================================
        if @w_veri_tarjeta = 'S'
        begin
            exec sp_at_ptl_valida_tarjeta --@w_return = 
                 @i_operacion         = 'U'
                ,@i_cod_tarjeta       = @i_cod_tarjeta
                ,@i_tarjeta           = @i_tarjeta
                ,@i_cuenta_debito     = @i_cuenta_debito
                ,@i_contador_bb       = @w_contador_bb
                ,@i_contador_red      = @w_contador_red
                ,@i_periodicidad_cupo          = @w_periodicidad_cupo           -- pqm actualizacion de cupo de la cuenta
                ,@i_saldo_cupo                 = @w_saldo_cupo                  -- pqm actualizacion de cupo de la cuenta
                ,@i_cupo_compras_utilizado     = @w_cupo_compras_utilizado      -- pqm actualizacion de cupo de la cuenta
                ,@i_transacciones_usadas       = @w_transacciones_usadas        -- pqm actualizacion de cupo de la cuenta
                ,@i_saldo_cupo_cta             = @w_saldo_cupo_cta              -- pqm actualizacion de cupo de la cuenta
                ,@i_cupo_compras_utilizado_cta = @w_cupo_compras_utilizado_cta  -- pqm actualizacion de cupo de la cuenta
                ,@i_transacciones_usadas_cta   = @w_transacciones_usadas_cta    -- pqm actualizacion de cupo de la cuenta
                ,@i_fecha_trans             = @i_fecha_trans                    --jcveliz Caso Actualizacion Cupo OFFLINE 11/DIC/2013
                ,@o_codigo_error      = @o_codigo_error out 

            if @o_codigo_error <> 0
            begin
               rollback transaction
               goto lbl_error
            end
        end
        
        -----agregar lo de la promocion para compras desde MEdianet para mundical
        -----JCGV CAJ-CC-SGC00014914
        declare @w_pin_entry_capab char(1)
        select @w_pin_entry_capab=''
        
        
        set @w_pin_entry_capab=substring(isnull(@i_iso_field22,''),3,1) 
        
        --Con esto valido que la 
        if @w_promocion='S' and @i_origen = 'MDNET' and @w_pin_entry_capab='1' and @i_dispositivo ='01' 
        begin
            exec @w_return =sp_at_ptl_promo_mundial_pos 
                 @i_cod_tarjeta         =@i_cod_tarjeta
                ,@i_reverso             =@i_reverso
                ,@i_cod_trx             =@i_trn 
                ,@i_recibo              =@i_atm_secuencial
                ,@i_terminal            =@i_cajero
                ,@i_fecha_trx           =@i_fecha_trans
                ,@i_fecha_concilia      =@i_fecha_contable  
                ,@i_valor_trx           =@i_valor
                ,@o_indicador_ganador   =@w_indicador_ganador   out
                ,@o_message_ganador     =@w_message_ganador out
                ,@o_code_return =@o_codigo_error out 
            
                    
                
            if @w_return <> 0
            begin
               rollback transaction
               goto lbl_error
            end
                
                
            if @w_indicador_ganador='S' begin
                set @o_mensaje=@w_message_ganador
                set @o_indicador_ganador=@w_indicador_ganador
            end
        end
    
		    
    commit tran RETIRO
    
    if @w_notificaSMS = 'S'
    begin
    --==============================================================
    --print '-- ENVIA NOTIFICACIONES AL CLIENTE'
    --==============================================================
    exec @w_return = sp_at_ptl_notifica_sms
               @i_trn           = @i_trn
              ,@i_fecha_trans   = @i_fecha_trans
              ,@i_cuenta_debito = @i_cuenta_debito
              ,@i_cuenta_credito= @i_cuenta_credito
              ,@i_prodcre       = @w_prodcre
              ,@i_proddeb       = @w_proddeb
              ,@i_valor         = @i_valor
              ,@i_comision      = @w_comision
              ,@i_atm_secuencial= @i_atm_secuencial
              ,@i_empresa       = 0
              ,@i_dispositivo   = @w_dispositivo                          
              ,@i_canal         = @w_canal
              ,@i_pais          = @i_pais              
              ,@i_tarjeta       = @i_tarjeta    
              ,@i_sec_tarjeta   = @i_cod_tarjeta
              ,@i_tipo_tarjeta  = @w_tipo_tarjeta
              ,@i_nombre_tarjeta= @w_nombre_tarjeta
              ,@i_cliente       = @w_cliente
              ,@i_reverso       = @i_reverso
              ,@i_retardo_SMS   = @w_retardo_SMS
              ,@o_codigo_error  = @o_codigo_error out 
            

            if @w_return <> 0
                begin
                      select @o_codigo_error = 160111
                      select @w_return = @o_codigo_error
                      goto lbl_error
                end
        
    end

    if @i_trn in (16406,16407) and  ( @i_pais != 'EC')  --ref-MGT20160607-ISD
        select @o_iso_field108resp = @w_monto_acum_isd
		--select @o_iso_field108resp = 'S'
		
        
return 0

--==============================================================    
lbl_error:
--==============================================================

    select @o_iso_field108resp = 'N'        --ref-MGT20160607-ISD
    
    if @w_return <> 0 
        select @o_codigo_error = @w_return
    
    insert into at_ruteo values
    (
        @i_cajero,          @i_trn,         @i_atm_secuencial,
        @i_atm_secuencial,  @i_tarjeta,     @i_fecha_trans,
        @i_fecha_contable,  @i_valor,       @i_cuenta_debito,
        @i_cuenta_credito,  @i_reverso,     @w_aba_banco,
        @w_offline,         @i_origen,      @i_oficina,
        @w_rol,             @i_reentry,     @o_codigo_error
    )
    if @@error<>0  
        set @w_return=160111 
    
    return @w_return
end
go
