/*************************************************************************/
/* Archivo:            dir_dml.sp                                        */
/* Motor de Base:      SYBASE                                            */
/* Base de datos:      cobis                                             */
/* Aplicacion:         MIS                                               */
/* Stored procedure:   sp_direccion_dml                                  */
/* Disenado por:       Mauricio Bayas/Sandra Ortiz                       */
/* Fecha de escritura: 07-Nov-1992                                       */
/* Servidor: 	       SYBASE					  	 */
/* Aplicacion: 	       MIS		 	          	         */
/* Procesamiento:      OLTP			  		         */
/*************************************************************************/
/*                      IMPORTANTE                                       */
/* Este programa es parte de los paquetes bancarios propiedad            */
/* de "BANCO BOLIVARIANO"                                                */
/* Su uso no autorizado queda expresamente prohibido asi como            */
/* cualquier alteracion o agregado hecho por alguno de sus               */
/* usuarios sin el debido consentimiento por escrito de la               */
/* Presidencia Ejecutiva de BANCO BOLIVARIANO.                           */
/*************************************************************************/
/* PROPOSITO:                                                            */
/*  OLTP - Este programa procesa las transacciones DML de direcciones.   */
/*************************************************************************/
/* MODIFICACIONES:                                                       */
/*************************************************************************/
/* REF    FECHA       AUTOR      TAREA RATIONAL                          */
/*   1  07/Nov/1992  MDavila                                             */
/*      Emision Inicial.					         */
/*-----------------------------------------------------------------------*/
/*   2	12/Ene/1993  LCarvajal                                           */
/*      Tabla de errores, variables de debug.			         */
/*-----------------------------------------------------------------------*/
/*   3	14/Abr/1994  CRodriguez                                          */
/*      Considerar oficina en la que influye la direccion y la           */
/*      confirmacion de la misma.                                        */
/*-----------------------------------------------------------------------*/
/*   4	04/May/1994  CRodriguez                                          */
/*      Considerar la zona y el sector.				         */
/*-----------------------------------------------------------------------*/
/*   5	22/Ago/1996  GMorales                                            */
/*      Aumentar long.de variables para descripcion.		         */
/*-----------------------------------------------------------------------*/
/*   6	16/Ago/1999  TCervantes                                          */
/*      No grabar transaccion de servicio para registro enviado por      */
/*      cambios.						         */
/*-----------------------------------------------------------------------*/
/*   7	28/oct/1999  TCervantes                                          */
/*      Grabar la transaccion de servicio referenciando la tabla y no la */
/*      vista.						                 */
/*-----------------------------------------------------------------------*/
/*   8	08/nov/1999  TCervantes                                          */
/*      Referenciar indices de las tablas cl_direccion y cl_det_producto.*/
/*-----------------------------------------------------------------------*/
/*   9	11/AGO/2003  TCervantesZ                                         */
/*      Incluir parametro de si es llamado por proceso batch.		 */
/*-----------------------------------------------------------------------*/
/*  10	14/ENE/2004  TCervantesZ                                         */
/*      Incluir los campos de envio de correspondencia y parroquia.	 */
/*-----------------------------------------------------------------------*/
/*  11	14/abr/2004  FMejia                                              */
/*      Grabar en cob_ahoros direccion de envio de correspondencia.	 */
/*-----------------------------------------------------------------------*/
/*  12	08/OCT/2004  TCervantes Z.                                       */
/*      Incluir la fecha de verificacion del registro.			 */
/*-----------------------------------------------------------------------*/
/*  13	01/NOV/2005  TCervantes Z.                                       */
/*      Incluir los campos nombre y cargo de la persona que confirma la  */
/*      referencia.							 */
/*-----------------------------------------------------------------------*/
/*  14	15/MAY/2006  AMejiaF.                                            */
/*      Incluir campo:usuario reg y modific, considerar Actualizacion    */
/*      Presencial.							 */
/*-----------------------------------------------------------------------*/
/*  15	02/AGO/2006  AMejiaF.                                            */
/*      Eliminar con validaciones a temporales y valida el maximo de     */
/*      direcciones por ente.						 */
/*-----------------------------------------------------------------------*/
/*  16	02/AGO/2007  TCervantesZ                                         */
/*      Incluir el campo de tipo de verificado con inconsistencia.	 */
/*-----------------------------------------------------------------------*/
/*  17	08/FEB/2008  AMejiaF.                                            */
/*      Alertas por cambio direccion de envio de estado de cuenta.	 */
/*-----------------------------------------------------------------------*/
/*  18	27/OCT/2008  ARodriguezV                                         */
/*      Agregar punto de referencia validar cantidad de direcciones.     */
/*      Nuevo campo te_pertenece, di_referencia en tablas historicas.	 */
/*-----------------------------------------------------------------------*/
/*  19	23/ABR/2009  AMejiaF.                                            */
/*      Corregir mensaje error 101267 por 101537.			 */
/*-----------------------------------------------------------------------*/
/*  20	16/OCT/2009  FRODRIGM                                            */
/*      En actualizacion de las direccion de envio correspondencia de    */
/*      las CtaAho excluir las cuentas asociadas a casilleros.           */
/*      Actualizar direccion de envio de estado de cuenta a todas las    */
/*      CtaCte del cliente.						 */
/*-----------------------------------------------------------------------*/
/*  21  11/Nov/2009  FRODRIGM    MIS-CC-7852                             */
/*      Inserta registros en tabla log direcciones envio EC TC.          */
/*      Se incluye parametro que indica el tipo de direccion de envio de */
/*      estado de cuenta.				                 */
/*      Valida si la direccion a modificar esta asociada con las         */
/*      direcciones de envio de estado de cuenta.	                 */
/*-----------------------------------------------------------------------*/
/*  22  14/Jul/2010  FRODRIGM    MIS-6954                                */
/*      Actualiza tipo de direccion en tabla de direcciones de envio de  */
/*      estados de cuenta de tarjetas de credito.	                 */
/*-----------------------------------------------------------------------*/
/*  23  19/Jul/2010  FRODRIGM    MIS-6965                                */
/*      Valida si direccion a modificar es del mismo tipo de la asociada */
/*      a envio ECTC no grabar en cl_log_dir_envio_ec.                   */
/*-----------------------------------------------------------------------*/
/*  24  18/Mar/2011  AMejiaF.    VCR-7796                                */
/*      Valida tipo de direccion en cl_dir_envio_tarj_cred.              */
/*-----------------------------------------------------------------------*/
/*  25  10/Ago/2011  FRODRIGM    REAPER-283-CU-1656                      */
/*      Modificar Vigencia de la Referencia.		                 */
/*      Incluye campos Direccion Planilla.		                 */
/*-----------------------------------------------------------------------*/
/*  26  07/Sep/2011  FRODRIGM    REAPER-283-CU-1663                      */
/*      Guarda informacion de log para vreferen.		         */
/*-----------------------------------------------------------------------*/
/*  27  13/Sep/2011  FRODRIGM    MIS-CC-10540                            */
/*      Validacion para eliminar caracteres especiales.                  */
/*-----------------------------------------------------------------------*/
/*  28  27/Ago/2012  ARODRIGV    VCR-SGC00003457                         */
/*      Cuentas Cerradas Inconsistencia.			         */
/*-----------------------------------------------------------------------*/
/*  29  14/May/2013  MFLORESJ    MIS-CE-SGC00009132                      */
/*      Eliminar caracteres Especiales en campos de direccion.           */
/*-----------------------------------------------------------------------*/
/*  30  15/May/2013  MFLORESJ    MISCON-AP-SGC00008120-SGC00008123       */
/*      Se agrega campo canton Lineamientos Q.A                          */
/*-----------------------------------------------------------------------*/
/*  31  27/Ago/2015  FRODRIGM    MIS-CC-SGC00021188                      */
/*      Envio Notificacion al cliente por cambio de direccion.           */
/*-----------------------------------------------------------------------*/
/*  32  24/Feb/2016  FRODRIGM    RHH-CC-SGC00021482                      */
/*      Modifica Envio de Notificacion por cambio direccion.             */
/*-----------------------------------------------------------------------*/
/*  33  21/Mar/2017  FGonzalB    MIS-CC-SGC00028234                      */
/*      Actualizar parametro TPVGRE a tipo smallint                      */
/*-----------------------------------------------------------------------*/
/*  34  16/Jun/2017  FRODRIGM    CARTMX-AP-SGC00028392-SGC00028728       */
/*      Incluir parametro de control por actualizacion masiva de clientes*/
/*      por compra de cartera.                                           */
/*-----------------------------------------------------------------------*/
/*  35  17/Abr/2019  FMIRANDG    MPAC-AP-SGC00034749-SGC00034752         */
/*      Validacion de marca Presencial                                   */
/*-----------------------------------------------------------------------*/
/*  36  22/Jun/2020  LLANCHIP    NPME-AP-SGC00035818-SGC00037402         */
/*                             Se retornan campos para enviar            */
/*                             notificaciones usando microservicio de    */
/*                             latinia desde el frontend del MIS         */
/*-----------------------------------------------------------------------*/
/*  37  24/Nov/2020  lamorac     ONBEVOL-433                             */
/*                               Ajuste en el enceramiento de            */
/*                               direcciones laborales                   */
/*************************************************************************/
/*  38  30/sep/2021 jolaya          MIS-CC-SGC00041441                   */
/*      Modificacion sms para actualizacion de celulkar                  */
/*-----------------------------------------------------------------------*/
/*  39  15/Mar/2022 pholguiv     RCCR-AP-SGC00039317-SGC00039321  	 */
/*      			Validacion BATCH Cuentas                 */
/*-----------------------------------------------------------------------*/
/*  40  11/May/2022  LLANCHIP   LLANCHIP MIS-CC-SGC00042988              */
/*                             Se elimina invocación a sp_eventos        */
/*************************************************************************/

use cobis
go

/*--Ref 30 Ini Lineamientos de Q.A.*/

if exists (select 1 from sysobjects where name = 'sp_direccion_dml' and type ='P')
   drop proc dbo.sp_direccion_dml
go

if exists (select 1 from sysobjects where name = 'sp_direccion_dml' and type ='P')
   print '<<< DROP PROCEDURE sp_direccion_dml  -- ERROR -- >>>'
else
   print '== DROP PROCEDURE sp_direccion_dml *OK* =='
--Ref 30 Fin Lineamientos de Q.A.
go

create proc dbo.sp_direccion_dml (
@s_ssn			int          = null,
@s_user			login        = null,
@s_term			varchar(30)  = null,
@s_date			datetime     = null,
@s_srv			varchar(30)  = null,
@s_lsrv			varchar(30)  = null,
@s_ofi			smallint     = null,
@s_rol			smallint     = null,
@s_org_err		char(1)      = null,
@s_error		int          = null,
@s_sev			tinyint      = null,
@s_msg			descripcion  = null,
@s_org			char(1)      = null,
@t_debug		char(1)      = 'N',
@t_file			varchar(10)  = null,
@t_from			varchar(32)  = null,
@t_trn			int          = null,
@i_operacion		char(1),
@i_no_cobis		char(1)      = 'N',
@i_mensaje		char(1)      = 'S',
@i_producto		tinyint      = null,
@i_ente			int          = null,
@i_direccion		tinyint      = null,
@i_descripcion		varchar(255) = null,
@i_tipo			catalogo     = null,
@i_sector		catalogo     = '0',
@i_parroquia		smallint     = null,
@i_ciudad		smallint     = null,
@i_oficina		smallint     = null,
@i_zona			catalogo     = null,
@i_envio_crp		char(1)      = 'N',
@i_parroquia_ciu	smallint     = 0,
@i_observacion		varchar(255) = null,
@i_pto_referencia	varchar(255) = null,
@i_verificado		char(1)      = 'N',
@i_fecha_ver		datetime     = null,
@i_usuario_ver		login        = null,
@i_vigencia		char(1)      = 'N',
@i_fecha_caducidad	datetime     = null,
@i_nombre_verif		descripcion  = null,
@i_cargo_verif		varchar(20)  = null,
@i_ind_act_presenc	char(1)      = 'N',
@i_ind_val_maxdir	char(1)      = 'S',		-- valida el maximo de direcciones por ente
@i_tipo_verif_incns	catalogo     = null,
@i_bancarizacion	char(1)      = 'N',
@i_verifdirec		char(1)      = 'N',
@i_tipo_servicio	catalogo     = null,	--ref25
@i_cod_empresa		tinyint      = null,	--ref25
@i_direc_planilla	varchar(254) = null,	--ref25
@i_cod_rela_prop	catalogo     = null,	--ref25
@i_nom_propietario	descripcion  = null,	--ref25
@i_vreferen		char(1)      = 'N',     --ref26  identifica que el registro es actualizado desde el vreferen
@i_solicitud		int          = null,    --ref26  numero de solicitud vreferen
@i_anio			smallint     = null,    --ref26  anio de la solicitud vreferen
@o_direccion		tinyint      = null out,
@o_msj_error		varchar(132) = null out,
@o_sig_log_svr		int          = null out,--ref26 secuencial log solicitud vreferen
@i_canton		catalogo     = null,	--ref30
@i_valida		char(1)      = 'S' ,	--ref30 valida si ingresa el canton y parroq cuando sea 'S'
@i_val_dir		char(1)      = 'N',	--ref30 valida el tipo de direccion por tipo persona
@i_val_domicilio	char(1)      = 'S',	--ref30 valida que desde Vreferen acepte mas de una direccion
						-- de tipo domicilio para personas naturales con estado distinto a S de verificacion

@i_canal                varchar(10)  = null,	--ref31
@i_envio_notifica       char(1)      = 'S',	--ref31	--Cuando sean actualizaciones masivas se debe enviar el valor "N"

@e_actmasivacli         char(1)      = 'N'	--ref34
)
as
declare
@w_today                datetime,
@w_sp_name              varchar(32),
@w_return               int,
@w_codigo               int,
@w_num                  int,
@w_min_dir              tinyint,
@w_max_dir              tinyint,
@w_subtipo              char(1),
@w_num_dir              tinyint,
--@w_direccion            tinyint,
@w_telefono             tinyint,
@w_cod_alterno	        smallint,
@w_ctacte               char(10),
/*<REF 33 @w_tiempo_vigencia      tinyint, REF 33>*/
--<REF 33
@w_tiempo_vigencia      smallint,
--REF 33>
@w_descripcion          varchar(255),
@w_usuario_reg          login,
@w_usuario_mod          login,
@w_fecha_registro       datetime,
@w_fecha_modificacion   datetime,
@w_secuencial_hd        int,
@w_tipo                 catalogo,
@w_sector               catalogo,
@w_zona                 catalogo,
@w_parroquia            smallint,
@w_ciudad	        smallint,
@w_oficina              smallint,
@w_envio_crp            char(1),
@w_parroquia_ciu        smallint,
@w_observacion          varchar(255),
@w_pto_referencia   	varchar(255),
@w_verificado           char(1),
@w_fecha_ver            datetime,
@w_usuario_ver          login,
@w_vigencia             char(1),
@w_fecha_caducidad      datetime,
@w_nombre_verif         descripcion,
@w_cargo_verif          varchar(20),
@w_longuitud            smallint,
@w_descrip_iaux         varchar(255),
@w_descrip_waux         varchar(255),
@w_aux_codalt           int,
@w_tipo_verif_incns     catalogo,
@w_bancarizacion        char(1),
@w_ind_alerta           char(1),
@w_descdirant           varchar(255),
@w_cuenta_tarjeta       varchar(16),
@w_canton               catalogo,	--ref30
@v_descripcion          varchar(255),
@v_parroquia_ciu        smallint,
@v_canton               catalogo, 	--ref30
@v_tipo                 catalogo,
@v_sector               catalogo,
@v_zona                 catalogo,
@v_parroquia            smallint,
@v_ciudad               smallint,
@v_oficina              smallint,
@v_envio_crp            char(1),
@v_observacion          varchar(255),
@v_pto_referencia   	varchar(255),
@v_verificado           char(1),
@v_fecha_ver            datetime,
@v_vigencia             char(1),
@v_usuario_ver          login,
@v_fecha_caducidad      datetime,
@v_nombre_verif         descripcion,
@v_cargo_verif          varchar(20),
@v_tipo_verif_incns     catalogo,
@w_direccion_tc	        smallint,	--ref22  se utiliza esta variable para que la comparacion sea con un campo del mismo tipo
@w_tipo_accion          char(1),	--ref23  tipo de accion a grabar en la tabla log de envio ECTC
@w_tipo_direc_envio     varchar(10),	--ref24  tipo_direc_envio
@w_tipo_servicio        catalogo,	--ref25
@w_cod_empresa          tinyint,	--ref25
@w_direc_planilla       varchar(254),	--ref25
@w_cod_rela_prop        catalogo,	--ref25
@w_nom_propietario      descripcion,	--ref25
@v_tipo_servicio        catalogo,	--ref25
@v_cod_empresa          tinyint,	--ref25
@v_direc_planilla       varchar(254),	--ref25
@v_cod_rela_prop        catalogo,	--ref25
@v_nom_propietario      descripcion,	--ref25
@w_cod_reg_vref         varchar(30),    --ref26
@w_col                  tinyint,        --ref29
@w_ind                  tinyint,        --ref29
@w_cadena               varchar(50),    --ref29
@w_reemplazo            char(1),        --ref29
@w_cadenaR              varchar(50),    --ref29
@w_caracter             char(1),        --ref29
@w_contini		int,		--ref30
@w_contfin		int,		--ref30

@w_fecha_reg            datetime,	--ref31
@w_fecha_crea_cli       datetime,	--ref31
@w_servicio             varchar(40),    --ref31
@w_idcliente            varchar(30), 	--ref31
@w_nombrecli 		varchar(64),	--ref31
@w_p_apellido           varchar(64),    --ref31
@w_s_apellido           varchar(64),    --ref31
@w_canal                varchar(10),	--ref31
--@w_desc_dir		varchar(10),	--ref31
@w_mail 		varchar(64),	--ref31
@w_envio_notifica       char(1),   --ref32
--<REF 35
--FMI 12/ABRIL/2019
@v_varifica_presencial char(1),
@v_presencial_ant char(1)
--REF 35>
	,@w_fecha			varchar(10), 	--ref36
	@w_hora				varchar(10),	--ref36
	@w_medio			varchar(70),	--ref36
	@w_idcli_enm		varchar(30),	--ref36
	@w_nombrecliente 	varchar(64),	--ref36
	@w_nemonico     	varchar(30),		--ref36
	@w_serv_del_dir 	varchar(40),	--ref36
	@w_celular			varchar(20) 	--ref36
set nocount on

select @w_sp_name = 'sp_direccion_dml',
       @w_today = getdate()

if @t_debug = 'S'
begin
  exec cobis..sp_begin_debug @t_file = @t_file
  select '/** Stored Procedure **/ ' = @w_sp_name,
	s_ssn		  = @s_ssn,
	s_user		  = @s_user,
	s_term		  = @s_term,
	s_date		  = @s_date,
	s_srv		  = @s_srv,
	s_lsrv		  = @s_lsrv,
	s_ofi		  = @s_ofi,
	s_rol		  = @s_rol,
	s_org_err	  = @s_org_err,
	s_error		  = @s_error,
	s_sev		  = @s_sev,
	s_msg		  = @s_msg,
	s_org		  = @s_org,
	t_trn		  = @t_trn,
	t_file		  = @t_file,
	t_from		  = @t_from,
	i_operacion	  = @i_operacion,
	i_no_cobis	  = @i_no_cobis,
	i_mensaje	  = @i_mensaje,
	i_producto	  = @i_producto,
	i_ente		  = @i_ente,
	i_direccion	  = @i_direccion,
	i_descripcion	  = @i_descripcion,
	i_tipo		  = @i_tipo,
	i_sector	  = @i_sector,
	i_parroquia	  = @i_parroquia,
	i_ciudad	  = @i_ciudad,
	i_oficina	  = @i_oficina,
	i_envio_crp	  = @i_envio_crp,
	i_parroquia_ciu	  = @i_parroquia_ciu,
	i_observacion	  = @i_observacion,
	i_verificado	  = @i_verificado,
	i_nombre_verif	  = @i_nombre_verif,
	i_cargo_verif	  = @i_cargo_verif,
	i_tipo_servicio	  = @i_tipo_servicio,		--ref25
	i_cod_empresa	  = @i_cod_empresa,		--ref25
	i_direc_planilla  = @i_direc_planilla,		--ref25
	i_cod_rela_prop	  = @i_cod_rela_prop,		--ref25
	i_nom_propietario = @i_nom_propietario,		--ref25
	i_vreferen	  = @i_vreferen,		--ref26
	i_solicitud	  = @i_solicitud,		--ref26
	i_anio		  = @i_anio,			--ref26
	i_canton	  = @i_canton,			--ref30
	i_canal           = @i_canal,		--ref31
	i_envio_notifica  = @i_envio_notifica	--ref31

   exec cobis..sp_end_debug
end

--ref31 Ini
if @i_ente = 0
   begin
     /* 'No existe ente' */
     select @w_num = 101042
     goto mensaje_error
   end

select @w_fecha_reg = convert(varchar(10), @w_today, 101)
--<REF 35
--FMI 12/ABRIL/2019
set @v_varifica_presencial = 'V'
--REF 35>

select @w_subtipo = en_subtipo,
       @w_fecha_crea_cli = convert(varchar(10), en_fecha_crea, 101),
       @w_idcliente  = isnull(en_ced_ruc,isnull(p_pasaporte,'')),
       @w_nombrecli  = isnull(en_nombre,''),
       @w_p_apellido = isnull(p_p_apellido,''),
       @w_s_apellido = isnull(p_s_apellido,'')
from cobis..cl_ente
where en_ente = @i_ente

if @@rowcount = 0
   begin
     /* 'No existe ente' */
     select @w_num = 101042
     goto mensaje_error
   end

--Obtiene el email del cliente
if @i_envio_notifica = 'S' and @w_subtipo = 'P'
   begin
     select top 1 @w_mail = de_descripcion
     from cobis..cl_direccion_email
     where de_ente = @i_ente
     and de_tipo = 'E'
     order by de_fecha_modificacion desc

     if @@rowcount = 0
        select @w_mail = ''
   end
--ref31 Fin

----ref36 Obtiene el celular del cliente
if @i_envio_notifica = 'S' and @w_subtipo = 'P'
   begin
    select top 1 @w_celular = de_descripcion
	from cobis..cl_direccion_email
	where de_ente = @i_ente
	and de_tipo = 'M'
	order by de_fecha_modificacion desc

     if @@rowcount = 0
        select @w_celular = ''
   end
--ref36 Fin

/** Insert **/
if @i_operacion = 'I'
begin
if @t_trn = 109
begin
  /* Verificacion de claves foraneas */
  if exists(select 1 from cobis..cl_producto where pd_producto = @i_producto)
     select @w_codigo = null
  else
     begin
       /* 'No existe producto' */
       select @w_num = 101032
       goto mensaje_error
     end

  if exists (select 1 from cobis..cl_ciudad where ci_ciudad = @i_ciudad)
     select @w_codigo = null
  else
     begin
       /* 'No existe ciudad' */
       select @w_num = 101024
       goto mensaje_error
     end

  if exists(select 1 from cobis..cl_parroquia where pq_ciudad = @i_ciudad and pq_parroquia = @i_parroquia)
     select @w_codigo = null
  else
     begin
       /* 'No existe parroquia' */
       select @w_num = 101037
       goto mensaje_error
     end

  --Inicio ref 30 : Validacion para cantones y parroquias de Ecuador
  if exists(select 1 from cobis..cl_canton_ciudad inner join cobis..cl_ciudad on cc_ciudad = ci_ciudad
	    where cc_ciudad = @i_ciudad and ci_pais = 1
     	    and ci_estado = 'V' and cc_estado = 'V')
     begin
       --Validacion que exista el canton
       if exists(select 1 from cobis..cl_canton_ciudad where cc_canton = @i_canton
  		 and cc_estado = 'V')
          select @w_codigo = null
       else
          begin
            /* 'NO EXISTE CANTON' */
            select @w_num = 101173
            goto mensaje_error
          end

       --Validacion que exista la parroquia
       if exists(select 1 from cobis..cl_canton_ciudad inner join cobis..cl_parroquia_ciudad on pc_ciudad = cc_ciudad
	         where cc_canton = @i_canton and pc_parroquia = @i_parroquia_ciu
		 and pc_parroquia_sib is not null and cc_estado = 'V')
          select @w_codigo = null
       else
          begin
            /* 'NO EXISTE LA PARROQUIA EN LA CIUDAD' */
            select @w_num = 101271
            goto mensaje_error
          end
     end
  --Fin ref 30

  if exists(select 1 from cobis..cl_oficina where of_oficina = @i_oficina)
     select @w_codigo = null
  else
     begin
       /* 'No existe oficina' */
       select @w_num = 101016
       goto mensaje_error
     end

  if (@i_tipo <> 'D' AND @i_tipo <> 'T' AND @i_tipo <> 'O')
     begin
       /* 'TIPO DIRECCION SOLO PUEDE SER  D T O ' */
       select @w_num = 101627
       goto mensaje_error
     end

  exec @w_return = cobis..sp_catalogo
       @t_debug        = @t_debug,
       @t_file         = @t_file,
       @t_from         = @w_sp_name,
       @i_operacion    = 'E',
       @i_tabla        = 'cl_tdireccion',
       @i_codigo       = @i_tipo

  if @w_return != 0
     begin
       /* 'No existe tipo de direccion' */
       select @w_num = 101025
       goto mensaje_error
     end

  if @i_envio_crp not in ('N', 'S')
     begin
       /* 'Parametro invalido' */
       select @w_num = 101114
       goto mensaje_error
     end

  /* verificar que exista el estado verificado */
  exec @w_return = cobis..sp_catalogo
       @t_debug	     = @t_debug,
       @t_file	     = @t_file,
       @t_from	     = @w_sp_name,
       @i_tabla	     = 'cl_estado_ver_ref',
       @i_operacion  = 'E',
       @i_codigo     = @i_verificado

  if @w_return != 0
     begin
       /* 'Parametro Invalido' */
       select @w_num = 101563
       goto mensaje_error
     end

  /* numero maximo de direcciones */
  if @w_subtipo = 'P'
     begin
       if @i_ind_val_maxdir = 'S'    -- indicador si valida el maximo de direcciones por ente
          begin
            select @w_num_dir = count(1) from cobis..cl_direccion where di_ente = @i_ente

            if @w_num_dir >= 3
               begin
                 /* 'EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES' */
                 select @w_num = 101267
                 goto mensaje_error
               end
          end
     end

  /* numero maximo de direcciones */
  if @w_subtipo = 'P'
     begin
       if @i_ind_val_maxdir = 'S'    -- indicador si valida el maximo de direcciones por ente
          begin
            if @i_tipo = 'D'
	       begin
	         --Inicio ref 30
	         if exists(select 1 from cobis..cl_direccion where di_ente = @i_ente and di_tipo = @i_tipo
	                   and di_direccion <> @i_direccion and di_verificado = 'S') and @i_val_dir ='S'
	            begin
		      /* 'EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES TIPO DOMICILIO' */
		      select @w_num = 101537
		      goto mensaje_error
	            end
	         --Fin ref30
                 select @w_num_dir = count(1) from cobis..cl_direccion where di_ente = @i_ente and di_tipo = @i_tipo

                 if @w_num_dir >= 1 and @i_val_domicilio = 'S'
                    begin
	              /* 'EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES TIPO DOMICILIO' */
                      select @w_num = 101537
                      goto mensaje_error
	            end
               end
	    else
	       if @i_tipo = 'T' or @i_tipo = 'O'
	          begin
                    select @w_num_dir = count(1) from cobis..cl_direccion where di_ente = @i_ente and di_tipo = @i_tipo

                    if @w_num_dir >= 2
                       begin
	                 /* 'EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES TIPO TRABAJO Y OTRO' */
                         select @w_num = 101521
                         goto mensaje_error
	               end
	          end
	    --Inicio ref 30
	    if not exists(select 1 from cobis..cl_direccion where di_ente = @i_ente and di_tipo ='D') and @i_val_dir = 'S'
	       begin
	         /* 'PERSONA NATURAL DEBE REGISTRARSE AL MENOS UNA DIRECCION TIPO [D]' */
	         select @w_num = 101730
	         goto mensaje_error
	       end
	    --Fin ref 30
          end
     end

  --Inicio ref 30
  if @w_subtipo = 'C'
     begin
       if not exists (select 1 from cobis..cl_direccion where di_ente = @i_ente and di_tipo ='T') and @i_val_dir ='S'
   	  begin
	    -- 'PERSONA JURIDICA DEBE REGISTRARSE AL MENOS UNA DIRECCION TIPO [T]'
	    select @w_num = 101731
	    goto mensaje_error
	  end

       if @i_tipo = 'D'
          begin
            --'Cliente juridico no debe tener direcciones de tipo Domicilio'
            select @w_num = 101713
            goto mensaje_error
	  end
     end
  --Fin ref 30

  /* obtener la zona del sector */
  select @i_zona = pq_zona from cobis..cl_parroquia where pq_ciudad = @i_ciudad and pq_parroquia = @i_parroquia

  /** obtener la vigencia de la referencia **/
  if @i_verificado in ('S','I','P')		--ref25
     begin

	   /*<REF 33 select @w_tiempo_vigencia = pa_tinyint from cobis..cl_parametro where pa_producto = 'MIS' and pa_nemonico = 'TPVGRE' REF 33>*/
	   --<REF 33
       select @w_tiempo_vigencia = pa_smallint from cobis..cl_parametro where pa_producto = 'MIS' and pa_nemonico = 'TPVGRE'
	   --REF 33>

       if @@rowcount = 0
          begin
            /* 'No existe parametro' */
            select @w_num = 101077
            goto mensaje_error
          end

       select @i_fecha_ver = @s_date, @i_usuario_ver = @s_user, @i_vigencia = 'S', @i_fecha_caducidad = dateadd(dd,@w_tiempo_vigencia,@s_date)
     end
  else
     begin
       select @i_fecha_ver = null,@i_usuario_ver = null,@i_nombre_verif = null,@i_cargo_verif = null,@i_vigencia = 'N',@i_fecha_caducidad = @s_date
     end

  --ref27 Elimina caracteres especiales a las variables @i_descripcion, @i_observacion--
  select @i_descripcion = str_replace(str_replace(str_replace(@i_descripcion, char(13), null), char(10), null), char(9), null)
  select @i_observacion = str_replace(str_replace(str_replace(@i_observacion, char(13), null), char(10), null), char(9), null)
  --ref27

  --Inicio Ref 29
  set @w_cadena  = '!"$%/()=?\¡¿' + '''' + '-_><{}[]^`+*~¨´@|¬°&#ñÑ'
  set @w_cadenaR = '                                YNnN'
  select @w_col = len(rtrim(@w_cadena))
  select @w_ind = 1
  while (@w_ind <= @w_col)
  begin
    set @w_reemplazo = substring(@w_cadenaR, @w_ind, 1)
    select @w_caracter = substring(@w_cadena , @w_ind, 1)
    set @i_descripcion = str_replace(@i_descripcion,@w_caracter,ltrim(@w_reemplazo))
    set @i_observacion = str_replace(@i_observacion,@w_caracter,ltrim(@w_reemplazo))
    set @w_ind = @w_ind + 1
  end

  set @i_descripcion = str_replace(@i_descripcion,'  ',' ')
  set @i_observacion = str_replace(@i_observacion,'  ',' ')

  -- Fin Ref 29

  /* secuencial de la transaccion de servicio */
  if @i_no_cobis = 'S'
     begin
       exec @w_return = cobis..sp_gen_sec
	    @s_date 	 = @s_date,
            @o_secuencial = @s_ssn out

       if @w_return != 0
          begin
            /* 'Error en creacion de transaccion de servicio'*/
            select @w_num = 103005
            goto mensaje_error
          end
     end

  --ref31 Ini  Obtiene el canal de donde se realizo la actualizacion de la direccion
  if @i_envio_notifica = 'S' and @w_subtipo = 'P'
     begin
       if @w_fecha_reg > @w_fecha_crea_cli
	  begin
            if @i_producto = 2 and @i_canal = 'MIS'
               select @w_canal = 'MIS'
            else
               if @i_producto = 166 and exists(select a.valor from cl_catalogo a, cl_tabla b where b.tabla = 'cl_cbpmnac'
                                               and a.tabla = b.codigo and a.codigo = @i_canal)
                  select @w_canal = 'BPM'
               else
                  if @i_producto = 166 and exists(select a.valor from cl_catalogo a, cl_tabla b where b.tabla = 'cl_cfinnac'
                                                  and a.tabla = b.codigo and a.codigo = @i_canal)
                     select @w_canal = 'FORMINT'
                  else
                     if @i_canal = 'VREFEREN'
                        select @w_canal = @i_canal
                     else
                        select @w_canal = 'OTROS'

            --Obtiene el servicio para la notificacion
	    select @w_servicio = 'Actualizacion de Direccion ' + case when @i_tipo = 'D' then 'de Domicilio'
                                         	     when @i_tipo = 'T' then 'de Trabajo'
                                         	     else 'Otros'
                                         	end
          end
     end
  --ref31 Fin

  Begin Tran
    /* ya existe direccion envio de correspondencia */
    if @i_envio_crp = 'S'
       begin
         update cobis..cl_direccion
	 set di_envio_crp = 'N'
	 where di_ente = @i_ente
	 and di_envio_crp = 'S'

         if @@error != 0
         begin
            /* 'Error en actualizacion de direccion' */
            select @w_num = 105034
            goto mensaje_error
         end
       end

    /* obtener el secuencial de la direccion */
    select @w_min_dir = min(di_direccion), @w_max_dir = max(di_direccion)
    from cobis..cl_direccion where di_ente = @i_ente

    if @@error != 0
       begin
         /* 'Error en incremento de direccion' */
         select @w_num = 105034
         goto mensaje_error
       end

    if @w_min_dir != 1
       select @o_direccion = 1
    else
       select @o_direccion = @w_max_dir + 1

    insert into cobis..cl_direccion(
      di_ente, di_direccion, di_descripcion, di_tipo, di_telefono, di_sector, di_zona, di_parroquia, di_ciudad, di_oficina,
      di_envio_crp, di_parroquia_ciu, di_observacion, di_fecha_registro, di_fecha_modificacion, di_verificado, di_fecha_ver,
      di_usuario_ver, di_vigencia, di_fecha_caducidad, di_nombre_verif, di_cargo_verif, di_usuario_reg, di_tipo_verif_incns,
      di_bancarizacion, di_referencia,
      di_tipo_servicio, di_empresa_servicio, di_direc_planilla, di_cod_rela_prop, di_nom_propietario, di_canton)	--ref 30
    values (@i_ente, @o_direccion, @i_descripcion, @i_tipo, 0, @i_sector, @i_zona, @i_parroquia, @i_ciudad, @i_oficina,
      @i_envio_crp, @i_parroquia_ciu, @i_observacion, @w_today, @w_today, @i_verificado, @i_fecha_ver,
      @i_usuario_ver, @i_vigencia, @i_fecha_caducidad, @i_nombre_verif, @i_cargo_verif, @s_user, @i_tipo_verif_incns,
      @i_bancarizacion, @i_pto_referencia,
      @i_tipo_servicio,	@i_cod_empresa, @i_direc_planilla, @i_cod_rela_prop, @i_nom_propietario,@i_canton)	--ref 30

    if @@error != 0
       begin
         /* 'Error en creacion de direccion'*/
         select @w_num = 103007
         goto mensaje_error
       end

    /* Transaccion servicios - cl_direccion */
    insert into cobis..ts_direccion(
      secuencial, tipo_transaccion, cod_alterno, clase, fecha, usuario, terminal, srv, lsrv, origen, rol,
      ente, direccion, descripcion, sector, zona, parroquia, ciudad, tipo, oficina, envio_crp, canton,parroquia_ciu, --ref 30
      observacion, verificado, fecha_ver, usuario_ver, vigencia, fecha_caducidad, nombre_verif, cargo_verif,
      tipo_verif_incns, bancarizacion, referencia,
      tipo_servicio, empresa_servicio, direc_planilla, cod_rela_prop, nom_propietario, canal)	--ref31	--ref25
    values(@s_ssn, @t_trn, @o_direccion, 'N', @w_today, @s_user, @s_term, @s_srv, @s_lsrv, @i_producto, @s_rol,
      @i_ente, @o_direccion, @i_descripcion, @i_sector, @i_zona, @i_parroquia, @i_ciudad, @i_tipo, @i_oficina, @i_envio_crp, @i_canton, @i_parroquia_ciu, --ref 30
      @i_observacion, @i_verificado, @i_fecha_ver, @i_usuario_ver, @i_vigencia, @i_fecha_caducidad, @i_nombre_verif, @i_cargo_verif,
      @i_tipo_verif_incns, @i_bancarizacion, @i_pto_referencia,
      @i_tipo_servicio,	@i_cod_empresa, @i_direc_planilla, @i_cod_rela_prop, @i_nom_propietario, @w_canal)  --ref31 --ref25

    if @@error != 0
       begin
         /* 'Error en creacion de transaccion de servicio' */
         select @w_num = 103005
         goto mensaje_error
       end

    --ref26 Guardar log para verificacion de referencias
    if @i_vreferen = 'S' and @i_observacion is not null
       begin
         exec sp_cseqnos
           @t_debug      = @t_debug,
           @t_file       = @t_file,
           @t_from       = @w_sp_name,
           @i_tabla      = 'cl_vr_solicitud_log',
           @o_siguiente  = @o_sig_log_svr out

         select @w_cod_reg_vref = convert(varchar(30), @o_direccion)

         insert into cl_vr_solicitud_log(
          sl_secuencial,sl_solicitud,sl_anio,sl_cliente,sl_tipo_reg,sl_cod_reg,sl_observacion,sl_fecha_ing,sl_usuario_ing)
         values(@o_sig_log_svr,@i_solicitud,@i_anio,@i_ente,'DIRECC',@w_cod_reg_vref,@i_observacion,@s_date,@s_user)

         if @@error != 0
            begin

              select @w_num = 101696
              goto mensaje_error
            end
       end
    --ref26

    --ref23
    --Valida que la direccion a ingresar no sea del mismo tipo de la que esta asociada para el envio de ECTC
    if exists (select 1 from cl_dir_envio_tarj_cred where dt_ente = @i_ente and dt_tipo_direc_envio = @i_tipo)
       select @w_tipo_accion = ''
    else
       begin
	 --ref21
         --Inserta registro en tabla log direcciones estado de cuenta tc --FRM Nov/2009
         insert into cl_log_dir_envio_ec(ld_fecha,ld_secuencial,ld_ente,ld_tipo_accion,ld_usuario,ld_oficina_usu,ld_tipo_dir_ant,ld_tipo_dir_act,
          ld_sec_direc_ant,ld_sec_direc_act,ld_cuenta_tarjeta,ld_valor_anterior,ld_valor_actual,ld_estado)   --I = ingresado  P= procesado
         values(@w_today,@s_ssn,@i_ente,'I',@s_user,@s_ofi,NULL,@i_tipo,
          NULL,@o_direccion,NULL,NULL,@i_descripcion,'I')
         --ref21

         if @@error != 0
            begin
              -- 'Error en creacion log direccion envio estado de cuenta'
              select @w_num = 101613
              goto mensaje_error
            end
       end
    --ref23

    --Se actualiza en todas las cuentas de ahorros las direccion de envio de correspondencia
    if @i_envio_crp  in ('S')
       begin
	 select @w_cod_alterno = 0
         DECLARE cursor_cuenta cursor for
         select ah_cta_banco from cob_ahorros..ah_cuenta where ah_cliente = @i_ente
	 for read only
         OPEN cursor_cuenta
         FETCH cursor_cuenta
         INTO @w_ctacte

         WHILE @@sqlstatus = 0
         begin /*while */

 	   select @w_cod_alterno = @w_cod_alterno + 1
           exec @w_return = sp_dir_est_cta
		@s_ssn          = @s_ssn,
		@s_user         = @s_user,
		@s_term         = @s_term,
		@s_date         = @s_date,
		@s_srv          = @s_srv,
		@s_lsrv         = @s_lsrv,
		@s_ofi          = @s_ofi,
		@s_rol          = @s_rol,
		@s_error        = @s_error,
		@s_sev          = @s_sev,
		@s_msg          = @s_msg,
	       	@t_debug	= @t_debug,
	       	@t_file	  	= @t_file,
	       	@t_from   	= @w_sp_name,
		@t_trn        	= 1307,
		@i_cod_alterno	= @w_cod_alterno,
		@i_producto   	= 2,
		@i_operacion  	= 'U',
		@i_cta        	= @w_ctacte ,
	       	@i_tipodir      = 'D',
	       	@i_direc       	= @o_direccion,
		@i_cli_ec 	= @i_ente,
		@i_tipo_cta 	= 'A'

           FETCH cursor_cuenta
           INTO @w_ctacte
         end  /* while */
         CLOSE cursor_cuenta
         deallocate cursor cursor_cuenta
       end

    --ref31 Ini
    if @i_envio_notifica = 'S' and @w_subtipo = 'P'
       begin
         if @w_fecha_reg > @w_fecha_crea_cli
            begin
              --Envia Notificacion al cliente por el cambio de direccion

      	      exec @w_return = cobis..sp_notif_cli_mod_dir
		@i_producto 	   = @i_producto,
		@i_ente     	   = @i_ente,
		@i_canalmod        = @i_canal,
		@i_oficina	   = @s_ofi,
		@i_envio_notifica  = @i_envio_notifica,	  --Cuando sean actualizaciones masivas se debe enviar el valor "N"
		@i_idcliente       = @w_idcliente,
		@i_today           = @w_today,
		@i_nombrecli 	   = @w_nombrecli,
	 	@i_p_apellido 	   = @w_p_apellido,
	 	@i_s_apellido 	   = @w_s_apellido,
		@i_servicio        = @w_servicio,
		@i_mail		   = @w_mail,
		@i_telefono	   = '0',
				@o_medio 			= @w_medio out, --ref36
				@o_nombrecli 		= @w_nombrecliente out, --ref36
				@o_fecha 			= @w_fecha out, --ref36
				@o_hora 			= @w_hora out, --ref36
				@o_idcli_enm 		= @w_idcli_enm out, --ref36
				@o_nemonico 			= @w_nemonico out --ref36

              if @w_return != 0
                 begin
                   --'Error en Notificacion al Cliente por Actualizacion de Datos'
                   select @w_num = @w_return
                   goto mensaje_error
                 end
					--ref36 Inicio
					--Retorna campos para envio de notificacion
					if @t_file!='ccreacli.s' --Ref39 --pholguiv
					select @w_medio,
						@w_nombrecliente,
						@w_fecha,
						@w_hora,
						@w_idcli_enm,
						@w_servicio,
						@w_mail,
						@w_nemonico,
						@o_direccion,
						@w_celular
					--ref36 Fin
			end
       end
    --ref31 Fin

  commit tran

if @t_file!='ccreacli.s' --Ref39 --pholguiv
  select @o_direccion

  return 0
end
else
begin
   /* 'No corresponde codigo de transaccion' */
   select @w_num = 151051
   goto mensaje_error
end
end

/** Update **/
if @i_operacion = 'U'
begin
if @t_trn = 110
begin
  select @w_direccion_tc = @i_direccion  --ref22
  --ref21
  /* Verifica Si la Dir a modificar esta asociada para el envio de EC (Cuenta Corriente y Tarjeta de Credito) --FRM NOV/2009*/
  if @i_verifdirec = 'S'
     begin
       if exists (select 1 from cob_cuentas..cc_ctacte where cc_cliente = @i_ente and cc_tipo_dir = 'D' and cc_direccion_ec = @i_direccion and cc_estado not in ('C', 'Q'))
          select @i_verifdirec
       else
          begin
            if exists (select 1 from cl_dir_envio_tarj_cred where dt_ente = @i_ente and dt_tipo_direc_envio in('D','T','O')
                       and dt_sec_direc_envio = @w_direccion_tc and dt_estado = 'A') 		--ref22
               select @i_verifdirec
            else
               select 'N'
          end

       return 0
     end
  --ref21
  select @w_ind_alerta = 'N'

  /* Verificacion de claves foraneas */
  if exists(select 1 from cobis..cl_producto where pd_producto = @i_producto)
     select @w_codigo = null
  else
     begin
       /* 'No existe producto' */
       select @w_num = 101032
       goto mensaje_error
     end

  if exists (select 1 from cobis..cl_ciudad where ci_ciudad = @i_ciudad)
     select @w_codigo = null
  else
     begin
       /* 'No existe ciudad' */
       select @w_num = 101024
       goto mensaje_error
     end

  if exists(select 1 from cobis..cl_parroquia where pq_ciudad = @i_ciudad and pq_parroquia = @i_parroquia)
     select @w_codigo = null
  else
     begin
       /* 'No existe parroquia' */
       select @w_num = 101037
       goto mensaje_error
     end

  --Inicio ref30 : Validacion para cantones y parroquias de Ecuador
  if exists(select 1 from cobis..cl_canton_ciudad inner join cobis..cl_ciudad on cc_ciudad = ci_ciudad
   	    where cc_ciudad = @i_ciudad and ci_pais = 1 and cc_estado = 'V')
     begin
       --Validacion que exista el canton
       if exists(select 1 from cobis..cl_canton_ciudad where cc_canton = @i_canton and cc_estado = 'V')
          select @w_codigo = null
       else
          begin
            /* 'NO EXISTE CANTON' */
            select @w_num = 101173
            goto mensaje_error
          end

       --Validacion que exista la parroquia
       if exists(select 1 from cobis..cl_canton_ciudad inner join cobis..cl_parroquia_ciudad on pc_ciudad = cc_ciudad
   	         where cc_canton = @i_canton and pc_parroquia = @i_parroquia_ciu and pc_parroquia_sib is not null
	         and pc_estado = 'V' and cc_estado = 'V')

          select @w_codigo = null
       else
          begin
            /* 'NO EXISTE LA PARROQUIA EN LA CIUDAD' */
            select @w_num = 101271
            goto mensaje_error
          end
     end
  --Fin ref30

  if exists (select 1 from cobis..cl_oficina where of_oficina = @i_oficina)
     select @w_codigo = null
  else
     begin
       /* 'No existe oficina' */
       select @w_num = 101016
       goto mensaje_error
     end

  if (@i_tipo <> 'D' AND @i_tipo <> 'T' AND @i_tipo <> 'O')
     begin
       /* 'TIPO DIRECCION SOLO PUEDE SER  D T O ' */
       select @w_num = 101627
       goto mensaje_error
     end

  exec @w_return = cobis..sp_catalogo
     @t_debug        = @t_debug,
     @t_file         = @t_file,
     @t_from         = @w_sp_name,
     @i_operacion    = 'E',
     @i_tabla        = 'cl_tdireccion',
     @i_codigo       = @i_tipo

  if @w_return != 0
     begin
       /* 'No existe tipo de direccion' */
       select @w_num = 101025
       goto mensaje_error
     end

  if @i_envio_crp not in ('S', 'N')
     begin
       /* 'Parametro Invalido' */
       select @w_num = 101114
       goto mensaje_error
     end

     /* verificar que exista el estado verificado */
     exec @w_return = cobis..sp_catalogo
  	@t_debug	= @t_debug,
	@t_file		= @t_file,
	@t_from		= @w_sp_name,
	@i_tabla	= 'cl_estado_ver_ref',
	@i_operacion	= 'E',
	@i_codigo	= @i_verificado

     if @w_return != 0
        begin
          /* 'Parametro Invalido' */
          select @w_num = 101563
          goto mensaje_error
        end

  select @i_zona = pq_zona from cobis..cl_parroquia where pq_ciudad = @i_ciudad and pq_parroquia = @i_parroquia

  /** Chequeo existencia de mas de tres dos o una D ****/

     /* valida solo 1 domicilio */
     if @w_subtipo = 'P'
        begin
          if @i_ind_val_maxdir = 'S'    -- indicador si valida el maximo de direcciones por ente
             begin
               if @i_tipo = 'D'
	          begin
	            --Inicio ref 30
	            if exists(select 1 from cobis..cl_direccion where di_ente = @i_ente and di_tipo = @i_tipo
	                      and di_direccion <> @i_direccion and di_verificado = 'S') and @i_val_dir ='S'
	               begin
	                 /* 'EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES TIPO DOMICILIO' */
		         select @w_num = 101537
                         goto mensaje_error
	               end
	            --Fin ref30

                    select @w_num_dir = count(1)
                    from cobis..cl_direccion where di_ente = @i_ente and di_tipo = @i_tipo and di_direccion <> @i_direccion

                    if @w_num_dir >= 1 and @i_val_domicilio = 'S'
                       begin
	                 /* 'EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES TIPO DOMICILIO' */
                         select @w_num = 101537
                         goto mensaje_error
	               end
	          end
	       else
	          if @i_tipo = 'T' or @i_tipo = 'O'
	             begin
                       select @w_num_dir = count(1)
                       from cobis..cl_direccion where di_ente = @i_ente and di_tipo = @i_tipo and di_direccion <> @i_direccion

                       if @w_num_dir >= 2
                          begin
	                    /* 'EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES TIPO TRABAJO Y OTRO' */
                            select @w_num = 101521
                            goto mensaje_error
	                  end
	             end

     	       --Inicio ref 30
	       if not exists(select 1 from cobis..cl_direccion where di_ente = @i_ente and di_tipo ='D') and @i_val_dir = 'S'
		  begin
		    /* 'PERSONA NATURAL DEBE REGISTRARSE AL MENOS UNA DIRECCION TIPO [D]' */
		    select @w_num = 101730
		    goto mensaje_error
		  end
	       --Fin ref 30
             end
        end

     --Inicio ref 30
     if @w_subtipo = 'C'
        begin
          if @i_tipo = 'D'
             begin
	       --'Cliente juridico no debe tener direcciones de tipo Domicilio'
	       select @w_num = 101713
	       goto mensaje_error
             end
        end
     --Fin ref 30

     --Si es verificado presencial o si verificado no debe tener tipo de verificacion inconsistencia
     if ((@i_verificado = 'P') or (@i_verificado = 'S'))				---ref28
        begin
	  select @i_tipo_verif_incns = null
        end

     /*****************************************************/

     --ref27 Elimina caracteres especiales a las variables @i_descripcion, @i_observacion--
     select @i_descripcion = str_replace(str_replace(str_replace(@i_descripcion, char(13), null), char(10), null), char(9), null)
     select @i_observacion = str_replace(str_replace(str_replace(@i_observacion, char(13), null), char(10), null), char(9), null)
     --ref27

     --Inicio Ref 29
     set @w_cadena  = '!"$%/()=?\¡¿' + '''' + '-_><{}[]^`+*~¨´@|¬°&#ñÑ'
     set @w_cadenaR = '                                YNnN'
     select @w_col = len(rtrim(@w_cadena))
     select @w_ind = 1
     while (@w_ind <= @w_col)
     begin
        set @w_reemplazo = substring(@w_cadenaR, @w_ind, 1)
        select @w_caracter = substring(@w_cadena , @w_ind, 1)
        set @i_descripcion = str_replace(@i_descripcion,@w_caracter,ltrim(@w_reemplazo))
        set @i_observacion = str_replace(@i_observacion,@w_caracter,ltrim(@w_reemplazo))
        set @w_ind = @w_ind + 1
     end

     set @i_descripcion = str_replace(@i_descripcion,'  ',' ')
     set @i_observacion = str_replace(@i_observacion,'  ',' ')
     -- Fin Ref 29

  /* Chequeo de campos a actualizar */
  select @w_descripcion      = di_descripcion,
	 @w_tipo             = di_tipo,
	 @w_parroquia        = di_parroquia,
	 @w_ciudad	     = di_ciudad,
	 @w_sector           = di_sector,
	 @w_zona	     = di_zona,
	 @w_oficina          = di_oficina,
         @w_envio_crp        = di_envio_crp,
	 @w_parroquia_ciu    = di_parroquia_ciu,
         @w_observacion      = di_observacion,
	 @w_verificado       = di_verificado,
         @w_fecha_ver        = di_fecha_ver,
         @w_usuario_ver      = di_usuario_ver,
         @w_vigencia         = di_vigencia,
         @w_fecha_caducidad  = di_fecha_caducidad,
         @w_nombre_verif     = di_nombre_verif,
         @w_cargo_verif      = di_cargo_verif,
         @w_tipo_verif_incns = di_tipo_verif_incns,
         @w_pto_referencia   = di_referencia,
         @w_tipo_servicio    = di_tipo_servicio,	--ref25
         @w_cod_empresa      = di_empresa_servicio, 	--ref25
         @w_direc_planilla   = di_direc_planilla, 	--ref25
         @w_cod_rela_prop    = di_cod_rela_prop, 	--ref25
         @w_nom_propietario  = di_nom_propietario,	--ref25
	 @w_canton           = di_canton  --ref 30
  from cobis..cl_direccion
  where di_ente = @i_ente
  and di_direccion = @i_direccion

  if @@rowcount = 0
     begin
       /* 'No existe direccion' */
       select @w_num = 101059
       goto mensaje_error
     end

  select @v_descripcion      = @w_descripcion,
         @w_descdirant       = @w_descripcion,
	 @v_tipo             = @w_tipo,
	 @v_parroquia        = @w_parroquia,
	 @v_ciudad           = @w_ciudad,
	 @v_sector           = @w_sector,
	 @v_zona             = @w_zona,
	 @v_oficina          = @w_oficina,
         @v_envio_crp        = @w_envio_crp,
	 @v_parroquia_ciu    = @w_parroquia_ciu,
         @v_observacion      = @w_observacion,
	 @v_verificado       = @w_verificado,
         @v_fecha_ver        = @w_fecha_ver,
         @v_usuario_ver      = @w_usuario_ver,
         @v_vigencia         = @w_vigencia,
         @v_fecha_caducidad  = @w_fecha_caducidad,
         @v_nombre_verif     = @w_nombre_verif,
         @v_cargo_verif      = @w_cargo_verif,
         @v_tipo_verif_incns = @w_tipo_verif_incns,
	 @v_pto_referencia   = @w_pto_referencia,
	 @v_tipo_servicio    = @w_tipo_servicio,	--ref25
	 @v_cod_empresa      = @w_cod_empresa, 		--ref25
	 @v_direc_planilla   = @w_direc_planilla, 	--ref25
	 @v_cod_rela_prop    = @w_cod_rela_prop, 	--ref25
	 @v_nom_propietario  = @w_nom_propietario,	--ref25
	 @v_canton           = @w_canton           	--ref30

  select @w_envio_notifica = 'N'	--ref32 --ref31

  --<REF 35
  --FMI 12/ABRIL/2019
     set @v_presencial_ant = @w_verificado
  --REF 35>

  /** obtener la fecha de verificacion de la referencia **/
  if @w_descripcion = @i_descripcion
     select @w_descripcion = null, @v_descripcion = null
  else
     begin
       -- verifica si se debe concatenar ciudadela/sector a la descripcion
       if @i_zona = 'X'
          select @w_descripcion = @i_descripcion, @w_ind_alerta = 'S'
       else
          begin
            -- si solo se le concatena ciudadela/sector no debe cambiar a actualizado presencial
            select @w_longuitud = char_length(@i_descripcion)
            select @w_descrip_iaux = ltrim(rtrim(substring(@i_descripcion, charindex(char(44), @i_descripcion) + 1, @w_longuitud)))

            select @w_longuitud = char_length(@w_descripcion)
            select @w_descrip_waux = ltrim(rtrim(substring(@w_descripcion, charindex(char(44), @w_descripcion) + 1, @w_longuitud)))

            if @w_descrip_iaux = @w_descrip_waux
               select @w_longuitud = 0
            else
               select @w_descripcion = @i_descripcion, @w_ind_alerta = 'S'
          end

       select @w_envio_notifica = 'S'	--ref32	--ref31
     end

  if @w_canton = @i_canton --ref 30
     select @w_canton = null, @v_canton= null
  else
   begin
      select @w_canton = @i_canton, @w_envio_notifica = 'S'	--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_pto_referencia = @i_pto_referencia
     select @w_pto_referencia = null, @v_pto_referencia= null
  else
   begin
      select @w_pto_referencia = @i_pto_referencia, @w_envio_notifica = 'S'	--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_envio_crp = @i_envio_crp
     select @w_envio_crp = null, @v_envio_crp = null
  else
    begin
	  select @w_envio_crp = @i_envio_crp, @w_envio_notifica = 'S'	--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
     end

  if @w_tipo = @i_tipo
     select @w_tipo = null, @v_tipo = null
  else
   begin
     select @w_tipo = @i_tipo, @w_envio_notifica = 'S'		--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_sector = @i_sector
     select @w_sector = null, @v_sector = null
  else
     begin
       if @i_sector <> '0'
          select @w_sector = @i_sector, @w_ind_alerta = 'S'

       select @w_envio_notifica = 'S'  	--ref32	--ref31
	   --<REF 35
	   --FMI 12/ABRIL/2019
	   set @v_varifica_presencial = 'N'
	   --REF 35>
     end

  if @w_parroquia = @i_parroquia
     select @w_parroquia = null, @v_parroquia = null
  else
   begin
     select @w_parroquia = @i_parroquia, @w_ind_alerta = 'S', @w_envio_notifica = 'S'  --ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_ciudad = @i_ciudad
     select @w_ciudad = null, @v_ciudad = null
  else
   begin
      select @w_ciudad = @i_ciudad, @w_ind_alerta = 'S', @w_envio_notifica = 'S'		--re32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_parroquia_ciu = @i_parroquia_ciu
     select @w_parroquia_ciu = null, @v_parroquia_ciu = null
  else
   begin
     select @w_parroquia_ciu = @i_parroquia_ciu, @w_ind_alerta = 'S', @w_envio_notifica = 'S'   --ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_zona = @i_zona
     select @w_zona = null, @v_zona = null
  else
   begin
     select @w_zona = @i_zona, @w_envio_notifica = 'S'		--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_oficina <> @i_oficina		--ref31
   begin
      select @w_envio_notifica = 'S'		--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_observacion = @i_observacion
     select @w_observacion = null, @v_observacion = null
  else
   begin
     select @w_observacion = @i_observacion
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  /** obtener la vigencia de la referencia **/
  if @i_verificado in ('S','I','P')		--ref25
     begin
	   /*<REF 33 select @w_tiempo_vigencia = pa_tinyint from cobis..cl_parametro where pa_producto = 'MIS' and pa_nemonico = 'TPVGRE' REF 33>*/
	   --<REF 33
       select @w_tiempo_vigencia = pa_smallint from cobis..cl_parametro where pa_producto = 'MIS' and pa_nemonico = 'TPVGRE'
	   --REF 33>

       if @@rowcount = 0
          begin
            /* 'No existe parametro' */
            select @w_num = 101077
            goto mensaje_error
          end

       select @i_fecha_ver = @s_date, @i_usuario_ver = @s_user, @i_vigencia = 'S', @i_fecha_caducidad = dateadd(dd,@w_tiempo_vigencia,@s_date)
     end
  else
     begin
       select @i_fecha_ver = @w_fecha_ver, @i_usuario_ver = @w_usuario_ver, @i_nombre_verif = @w_nombre_verif,
              @i_cargo_verif = @w_cargo_verif, @i_vigencia = 'N', @i_fecha_caducidad = @s_date
     end

  if @w_verificado = @i_verificado
     select @w_verificado = null, @v_verificado = null
  else
     select @w_verificado = @i_verificado

  if @w_fecha_ver = @i_fecha_ver
     select @w_fecha_ver = null, @v_fecha_ver = null
  else
   select @w_fecha_ver = @i_fecha_ver

  if @w_usuario_ver = @i_usuario_ver
     select @w_usuario_ver = null, @v_usuario_ver = null
  else
   select @w_usuario_ver = @i_usuario_ver

  if @w_vigencia = @i_vigencia
     select @w_vigencia = null, @v_vigencia = null
  else
   select @w_vigencia = @i_vigencia

  if @w_fecha_caducidad = @i_fecha_caducidad
     select @w_fecha_caducidad = null, @v_fecha_caducidad = null
  else
   select @w_fecha_caducidad = @i_fecha_caducidad

  if @w_nombre_verif = @i_nombre_verif
     select @w_nombre_verif = null, @v_nombre_verif = null
  else
   select @w_nombre_verif = @i_nombre_verif

  if @w_cargo_verif = @i_cargo_verif
     select @w_cargo_verif = null, @v_cargo_verif = null
  else
   select @w_cargo_verif = @i_cargo_verif

  if @w_tipo_verif_incns = @i_tipo_verif_incns
     select @w_tipo_verif_incns = null, @v_tipo_verif_incns = null
  else
   select @w_tipo_verif_incns = @i_tipo_verif_incns

  /* La direccion es de envio de correspondencia */
  if @v_envio_crp = 'S' and @w_envio_crp = 'N'
     begin
       /* 'NO SE PUEDE DESMARCAR LA DIRECCION DE ENVIO DE CORRESPONDENCIA' */
       select @w_num = 101281
       goto mensaje_error
     end

  --ref25
  if @w_tipo_servicio = @i_tipo_servicio
     select @w_tipo_servicio = null, @v_tipo_servicio = null
  else
   begin
     select @w_tipo_servicio = @i_tipo_servicio, @w_envio_notifica = 'S'	--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_cod_empresa = @i_cod_empresa
     select @w_cod_empresa = null, @v_cod_empresa = null
  else
   begin
     select @w_cod_empresa = @i_cod_empresa, @w_envio_notifica = 'S'		--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_direc_planilla = @i_direc_planilla
     select @w_direc_planilla = null, @v_direc_planilla = null
  else
   begin
     select @w_direc_planilla = @i_direc_planilla, @w_envio_notifica = 'S'	--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_cod_rela_prop = @i_cod_rela_prop
     select @w_cod_rela_prop = null, @v_cod_rela_prop = null
  else
   begin
     select @w_cod_rela_prop = @i_cod_rela_prop, @w_envio_notifica = 'S'	--ref32	--ref31
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  if @w_nom_propietario = @i_nom_propietario
     select @w_nom_propietario = null, @v_nom_propietario = null
  else
   begin
     select @w_nom_propietario = @i_nom_propietario, @w_envio_notifica = 'S'	--ref32	--ref31
  --ref25
      --<REF 35
	  --FMI 12/ABRIL/2019
      set @v_varifica_presencial = 'N'
	  --REF 35>
   end

  /** secuencial de la transaccion de servicio **/
  if @i_no_cobis = 'S'
     begin
       exec @w_return = cobis..sp_gen_sec
	 @s_date 	 = @s_date,
         @o_secuencial = @s_ssn out

       if @w_return != 0
          begin
            /* 'Error en creacion de transaccion de servicio'*/
            select @w_num = 103005
            goto mensaje_error
          end
     end

 if @i_envio_notifica = 'N'				--ref32
    select @w_envio_notifica = @i_envio_notifica


  --ref31 Ini  Obtiene el canal de donde se realizo la actualizacion de la direccion
  if @w_envio_notifica = 'S' and @w_subtipo = 'P'	--ref32
     begin
       if @w_fecha_reg > @w_fecha_crea_cli
	  begin
            if @i_producto = 2 and @i_canal <> 'VREFEREN'
               select @w_canal = 'MIS'
            else
               if @i_producto = 166 and exists(select a.valor from cl_catalogo a, cl_tabla b where b.tabla = 'cl_cbpmnac'
                                               and a.tabla = b.codigo and a.codigo = @i_canal)
                  select @w_canal = 'BPM'
               else
                  if @i_producto = 166 and exists(select a.valor from cl_catalogo a, cl_tabla b where b.tabla = 'cl_cfinnac'
                                                  and a.tabla = b.codigo and a.codigo = @i_canal)
                     select @w_canal = 'FORMINT'
                  else
                     if @i_canal = 'VREFEREN'
                        select @w_canal = @i_canal
                     else
                        select @w_canal = 'OTROS'

     	    --Obtiene el servicio para la notificacion
     	    select @w_servicio = 'Actualizacion de Direccion ' + case when @i_tipo = 'D' then 'de Domicilio'
            	                                     when @i_tipo = 'T' then 'de Trabajo'
            	                                     else 'Otros'
            	                                end
          end
     end
  --ref31 Fin
  --<REF 35
  --FMI VALIDAR VERIFICADO PRESENCIAL 12/ABRIL/2019
  if @i_ind_act_presenc = 'V'
	 begin
	   set @i_verificado = @v_presencial_ant
     end
 IF @v_varifica_presencial = 'N' and @i_ind_act_presenc = 'V'
   begin
     select @w_num = 105109
     goto mensaje_error
   end
-----------------------------------------------
 --REF 35>

  Begin Tran

    /* La direccion es de envio de correspondencia */
    if @v_envio_crp = 'N' and @w_envio_crp = 'S'
       begin
         update cobis..cl_direccion
	 set di_envio_crp = 'N'
	 where di_ente = @i_ente
	 and di_envio_crp = 'S'

         if @@error != 0
            begin
              /* 'Error en actualizacion de direccion' */
              select @w_num = 105034
              goto mensaje_error
            end
       end

    /* actualizar la direccion */
    update cl_direccion
    set di_descripcion        = @i_descripcion,
	di_tipo               = @i_tipo,
	di_parroquia          = @i_parroquia,
	di_ciudad             = @i_ciudad,
	di_sector             = @i_sector,
	di_zona               = @i_zona,
	di_oficina            = @i_oficina,
        di_envio_crp          = @i_envio_crp,
	di_parroquia_ciu      = @i_parroquia_ciu,
        di_observacion        = @i_observacion,
	di_fecha_modificacion = @w_today,
	di_verificado         = @i_verificado,
	di_fecha_ver          = @i_fecha_ver,
	di_usuario_ver        = @i_usuario_ver,
        di_vigencia           = @i_vigencia,
	di_fecha_caducidad    = @i_fecha_caducidad,
        di_nombre_verif       = @i_nombre_verif,
        di_cargo_verif        = @i_cargo_verif,
        di_usuario_mod        = @s_user,
        di_tipo_verif_incns   = @i_tipo_verif_incns,
	di_referencia	      = @i_pto_referencia,
	di_tipo_servicio      = @i_tipo_servicio,	--ref25
	di_empresa_servicio   = @i_cod_empresa,		--ref25
	di_direc_planilla     = @i_direc_planilla,	--ref25
	di_cod_rela_prop      = @i_cod_rela_prop,	--ref25
        di_nom_propietario    = @i_nom_propietario,	--ref25
	di_canton             = @i_canton  --ref 30
    where di_ente = @i_ente
    and di_direccion = @i_direccion

    if @@error != 0
       begin
         /* 'Error en actualizacion de direccion' */
         select @w_num = 105034
         goto mensaje_error
       end

    /* Transaccion servicio - cl_direccion -datos previos */
    insert into cobis..ts_direccion (
      secuencial, tipo_transaccion, cod_alterno, clase, fecha, usuario, terminal, srv, lsrv, origen, rol,
      ente, direccion, descripcion, sector, zona, parroquia, ciudad, tipo, oficina,
      envio_crp, parroquia_ciu, observacion, verificado, fecha_ver, usuario_ver, vigencia, fecha_caducidad,
      nombre_verif, cargo_verif, tipo_verif_incns, referencia,
      tipo_servicio, empresa_servicio, direc_planilla, cod_rela_prop, nom_propietario)		--ref25
    values(@s_ssn, @t_trn, @i_direccion, 'P', @w_today, @s_user, @s_term, @s_srv, @s_lsrv, @i_producto, @s_rol,
      @i_ente, @i_direccion, @v_descripcion, @v_sector, @v_zona, @v_parroquia, @v_ciudad, @v_tipo, @v_oficina,
      @v_envio_crp, @v_parroquia_ciu, @v_observacion, @v_verificado, @v_fecha_ver, @v_usuario_ver, @v_vigencia, @v_fecha_caducidad,
      @v_nombre_verif, @v_cargo_verif, @v_tipo_verif_incns, @v_pto_referencia,
      @v_tipo_servicio, @v_cod_empresa, @v_direc_planilla, @v_cod_rela_prop, @v_nom_propietario)	--ref25

    if @@error != 0
       begin
	 /* 'Error en creacion de transaccion de servicio' */
         select @w_num = 103005
         goto mensaje_error
       end

    /* Transaccion servicio - cl_direccion -datos actuales */
    insert into cobis..ts_direccion (
      secuencial, tipo_transaccion, cod_alterno, clase, fecha, usuario, terminal, srv, lsrv, origen, rol,
      ente, direccion, descripcion, sector, zona, parroquia, ciudad, tipo, oficina,
      envio_crp, parroquia_ciu, observacion, verificado, fecha_ver, usuario_ver, vigencia, fecha_caducidad,
      nombre_verif, cargo_verif, tipo_verif_incns, referencia,
      tipo_servicio, empresa_servicio, direc_planilla, cod_rela_prop, nom_propietario, canal)	--ref31	--ref25
    values(@s_ssn, @t_trn, @i_direccion, 'A', @w_today, @s_user, @s_term, @s_srv, @s_lsrv, @i_producto, @s_rol,
      @i_ente, @i_direccion, @w_descripcion, @w_sector, @w_zona, @w_parroquia, @w_ciudad, @w_tipo, @w_oficina,
      @w_envio_crp, @w_parroquia_ciu, @w_observacion, @w_verificado, @w_fecha_ver, @w_usuario_ver, @w_vigencia, @w_fecha_caducidad,
      @w_nombre_verif, @w_cargo_verif, @w_tipo_verif_incns, @w_pto_referencia,
      @w_tipo_servicio, @w_cod_empresa, @w_direc_planilla, @w_cod_rela_prop, @w_nom_propietario, @w_canal)   --ref31  --ref25

    if @@error != 0
       begin
         /* 'Error en creacion de transaccion de servicio'*/
         select @w_num = 103005
         goto mensaje_error
       end

       --ref26 Guardar log para verificacion de referencias
       if @i_vreferen = 'S' and @i_observacion is not null
          begin
            exec sp_cseqnos
	      @t_debug      = @t_debug,
	      @t_file       = @t_file,
	      @t_from       = @w_sp_name,
	      @i_tabla      = 'cl_vr_solicitud_log',
	      @o_siguiente  = @o_sig_log_svr out

            select @w_cod_reg_vref = convert(varchar(30), @i_direccion)

            insert into cl_vr_solicitud_log(
             sl_secuencial,sl_solicitud,sl_anio,sl_cliente,sl_tipo_reg,sl_cod_reg,sl_observacion,sl_fecha_ing,sl_usuario_ing)
            values(@o_sig_log_svr,@i_solicitud,@i_anio,@i_ente,'DIRECC',@w_cod_reg_vref,@w_observacion,@s_date,@s_user)

            if @@error != 0
               begin

                 select @w_num = 101696
                 goto mensaje_error
               end
          end
       --ref26

       --ref21
       --obtiene el numero de la cuenta de la tarjeta
       if exists (select 1 from cl_dir_envio_tarj_cred where dt_ente = @i_ente and dt_tipo_direc_envio in('D','T','O')
                  and dt_sec_direc_envio = @w_direccion_tc and dt_estado = 'A')		--ref22
          select top 1 @w_cuenta_tarjeta = dt_cuenta
          from cl_dir_envio_tarj_cred
          where dt_ente = @i_ente and dt_tipo_direc_envio in('D','T','O')
          and dt_sec_direc_envio = @w_direccion_tc and dt_estado = 'A'			--ref22
       else
          select @w_cuenta_tarjeta = null
       --ref21

       --ref22
       --ref23
       --Modifica el tipo de direccion en la tabla de direccion envio EC TC y graba log de Modificacion/Asociacion
       select @w_tipo_accion = ''
       if exists(select 1 from cl_dir_envio_tarj_cred where dt_ente = @i_ente and dt_sec_direc_envio = @w_direccion_tc)
          begin
            --ref24
            select @w_tipo_direc_envio = dt_tipo_direc_envio
            from cl_dir_envio_tarj_cred
            where dt_ente = @i_ente and dt_sec_direc_envio = @w_direccion_tc and not dt_tipo_direc_envio in ('C', 'R', 'S')

            if @i_tipo = @w_tipo_direc_envio   --ref24
               select @w_tipo_accion = 'M'
            else
               begin
                 update cl_dir_envio_tarj_cred
                 set dt_tipo_direc_envio = @i_tipo
                 where dt_ente = @i_ente
                 and dt_sec_direc_envio = @w_direccion_tc
                 and not dt_tipo_direc_envio in ('C', 'R', 'S')   --ref24

                 if @@error != 0
		    begin
		      -- 'Error en actualizacion de direccion'
                      select @w_num = 105034
		      goto mensaje_error
		    end

                 select @w_tipo_accion = 'A'
               end
          end
       else
         begin
           --Valida que la direccion a modificar no sea del mismo tipo de la que esta asociada para el envio de ECTC
           if exists (select 1 from cl_dir_envio_tarj_cred where dt_ente = @i_ente and dt_tipo_direc_envio = @i_tipo)
              select @w_tipo_accion = ''
           else
              select @w_tipo_accion = 'M'
         end

       if @w_tipo_accion <> ''
          begin
            --Inserta registro en tabla log direcciones estado de cuenta tc --FRM Nov/2009
            insert into cl_log_dir_envio_ec(ld_fecha,ld_secuencial,ld_ente,ld_tipo_accion,ld_usuario,ld_oficina_usu,ld_tipo_dir_ant,ld_tipo_dir_act,
             ld_sec_direc_ant,ld_sec_direc_act,ld_cuenta_tarjeta,ld_valor_anterior,ld_valor_actual,ld_estado)   --I = ingresado  P= procesado
            values(@w_today,@s_ssn,@i_ente,@w_tipo_accion,@s_user,@s_ofi,@v_tipo,@i_tipo,
             @i_direccion,@i_direccion,@w_cuenta_tarjeta,@w_descdirant,@i_descripcion,'I')

            if @@error != 0
               begin
                 -- 'Error en creacion log direccion envio estado de cuenta'
                 select @w_num = 101613
                 goto mensaje_error
               end
          end
       --ref23
       --ref22

       --Se actualiza en todas las cuentas de ahorros las direccion de envio de correspondencia
       --Excluir las cuentas que esten asociadas a casilleros --FRM 15/oct/2009
       if @i_envio_crp  in ('S')
          begin
	    select @w_cod_alterno = 0

            DECLARE cursor_cuenta cursor for
            select ah_cta_banco from cob_ahorros..ah_cuenta where ah_cliente = @i_ente and ah_tipo_dir <> 'S'
	    for read only
            OPEN cursor_cuenta
            FETCH cursor_cuenta
            INTO @w_ctacte

            WHILE @@sqlstatus = 0
            begin /*while */
 	      select @w_cod_alterno = @w_cod_alterno + 1

              exec @w_return = sp_dir_est_cta
		@s_ssn             	= @s_ssn,
		@s_user             	= @s_user,
		@s_term             	= @s_term,
		@s_date            	= @s_date,
		@s_srv              	= @s_srv,
		@s_lsrv             	= @s_lsrv,
		@s_ofi              	= @s_ofi,
		@s_rol              	= @s_rol,
		@s_error            	= @s_error,
		@s_sev              	= @s_sev,
		@s_msg              	= @s_msg,
	      	@t_debug	  	= @t_debug,
	        @t_file	  		= @t_file,
	        @t_from   		= @w_sp_name,
		@t_trn        		= 1307,
		@i_cod_alterno		= @w_cod_alterno,
		@i_producto   		= 2,
		@i_operacion  		= 'U',
		@i_cta        		= @w_ctacte ,
	        @i_tipodir        	= 'D',
	        @i_direc       		= @i_direccion,
		@i_cli_ec 		= @i_ente,
		@i_tipo_cta 		= 'A'

              FETCH cursor_cuenta
              INTO @w_ctacte
            end  /* while */
            CLOSE cursor_cuenta
            deallocate cursor cursor_cuenta
          end

       --Se actualiza en todas las cuentas corrientes la direccion de envio de estado de cuenta --FRM 15/oct/2009
       select @w_cod_alterno = 0

       DECLARE cursor_ctacte1 cursor for
       select cc_cta_banco from cob_cuentas..cc_ctacte
       where cc_cliente = @i_ente
       and cc_tipo_dir = 'D' and cc_direccion_ec = @i_direccion
       and cc_estado <> 'C'
       for read only

       OPEN cursor_ctacte1
       FETCH cursor_ctacte1
       INTO @w_ctacte

       WHILE @@sqlstatus = 0
       begin /*while */
         select @w_cod_alterno = @w_cod_alterno + 1

         exec @w_return = sp_dir_est_cta
	   @s_ssn             	= @s_ssn,
	   @s_user             	= @s_user,
	   @s_term             	= @s_term,
	   @s_date            	= @s_date,
	   @s_srv              	= @s_srv,
	   @s_lsrv             	= @s_lsrv,
	   @s_ofi              	= @s_ofi,
	   @s_rol              	= @s_rol,
	   @s_error            	= @s_error,
	   @s_sev              	= @s_sev,
	   @s_msg              	= @s_msg,
	   @t_debug	  	= @t_debug,
	   @t_file	  	= @t_file,
	   @t_from   		= @w_sp_name,
	   @t_trn      		= 1307,
	   @i_cod_alterno	= @w_cod_alterno,
	   @i_producto   	= 2,
	   @i_operacion  	= 'U',
	   @i_cta        	= @w_ctacte ,
	   @i_tipodir        	= 'D',
	   @i_direc       	= @i_direccion,
	   @i_cli_ec 		= @i_ente,
	   @i_tipo_cta 		= 'C',
	   @i_canal 		= @i_canal --ref36

         FETCH cursor_ctacte1
         INTO @w_ctacte
       end  /* while */
       CLOSE cursor_ctacte1
       deallocate cursor cursor_ctacte1

       -------------------------------------------------
		--ref36 Ini
		if exists (select 1 from cobis..cl_catalogo where codigo = @i_canal and tabla in
						(select codigo from cobis..cl_tabla where tabla = 'mis_p_canalesnot') and estado = 'V')
			begin
				--ref36 Se retornan las cuentas para notificaciones
				select cc_cta_banco from cob_cuentas..cc_ctacte
				where cc_cliente = @i_ente
				and cc_tipo_dir = 'D' and cc_direccion_ec = @i_direccion
				and cc_estado not in ('C', 'Q')
			end
		/*else
			begin
		--ref36 Fin
			  if @w_ind_alerta = 'S' and @i_producto = 2
			  -- envio de alertas por cambio de datos de direccion de estado de cuenta
			  begin
			select @w_cod_alterno = 0

				DECLARE cursor_ctacte cursor for
				select cc_cta_banco from cob_cuentas..cc_ctacte
				where cc_cliente = @i_ente
				and cc_tipo_dir = 'D' and cc_direccion_ec = @i_direccion
				and cc_estado not in ('C', 'Q')
			for read only

				OPEN cursor_ctacte
				FETCH cursor_ctacte INTO @w_ctacte

				WHILE @@sqlstatus = 0
				begin --while
				  -- print 'cuenta'
				  select @w_cod_alterno = @w_cod_alterno + 1

				  exec @w_return = cob_internet..sp_eventos
					   @i_operacion = 'I',
					   @i_servicio = 'CDIRE',
					   @i_canal = 'MIS',
					   @i_producto = 3,
					   @i_cuenta   = @w_ctacte,
					   @i_cliente = @i_ente

				  if @@error != 0
				  begin
				  --'Error en creacion de transaccion de servicio'
					 select @w_num = 103005
					 goto mensaje_error
				  end

				  FETCH cursor_ctacte INTO @w_ctacte
				end   --while

				CLOSE cursor_ctacte
				deallocate cursor cursor_ctacte
			  end
		end --ref36
		*/
    --ref31 Ini
    if @w_envio_notifica = 'S' and @w_subtipo = 'P' 	--ref32
       begin
         if @w_fecha_reg > @w_fecha_crea_cli
            begin
              --Envia Notificacion al cliente por el cambio de direccion

      	      exec @w_return = cobis..sp_notif_cli_mod_dir
		@i_producto 	   = @i_producto,
		@i_ente     	   = @i_ente,
		@i_canalmod        = @i_canal,
		@i_oficina	   = @s_ofi,
		@i_envio_notifica  = @i_envio_notifica,	  --Cuando sean actualizaciones masivas se debe enviar el valor "N"
		@i_idcliente       = @w_idcliente,
		@i_today           = @w_today,
		@i_nombrecli 	   = @w_nombrecli,
	 	@i_p_apellido 	   = @w_p_apellido,
	 	@i_s_apellido 	   = @w_s_apellido,
		@i_servicio        = @w_servicio,
		@i_mail		   = @w_mail,
		@i_telefono	   = '0',
		@o_medio 			= @w_medio out, --ref36
		@o_nombrecli 		= @w_nombrecliente out, --ref36
		@o_fecha 			= @w_fecha out, --ref36
		@o_hora 			= @w_hora out, --ref36
		@o_idcli_enm 		= @w_idcli_enm out, --ref36
		@o_nemonico 			= @w_nemonico out --ref36

              if @w_return != 0
                 begin
                   --'Error en Notificacion al Cliente por Actualizacion de Datos'
                   select @w_num = @w_return
                   goto mensaje_error
                 end
		--ref36 Inicio
		--Retorna campos para envio de notificacion
		select @w_medio,
			@w_nombrecliente,
			@w_fecha,
			@w_hora,
			@w_idcli_enm,
			@w_servicio,
			@w_mail,
			@w_nemonico,
			@w_celular,
			@i_canal
		--ref36 Fin
			end
       end
    --ref31 Fin

  commit tran

return 0
end
else
   begin
     /* 'No corresponde codigo de transaccion' */
     select @w_num = 151051
     goto mensaje_error
   end
end

/** Delete **/
if @i_operacion = 'D'
begin
if @t_trn = 1226
begin
  if exists(select 1 from cobis..cl_producto where pd_producto = @i_producto)
     select @w_codigo = null
  else
     begin
       /* 'No existe producto' */
       select @w_num = 101032
       goto mensaje_error
     end

  /* Campos para transaccion de  servicios */
  select @w_descripcion        = di_descripcion,
	 @w_tipo               = di_tipo,
	 @w_parroquia          = di_parroquia,
	 @w_ciudad	       = di_ciudad,
	 @w_sector             = di_sector,
	 @w_zona	       = di_zona,
	 @w_oficina            = di_oficina,
         @w_envio_crp          = di_envio_crp,
         @w_parroquia_ciu      = di_parroquia_ciu,
         @w_observacion        = di_observacion,
         @w_fecha_registro     = di_fecha_registro,
         @w_fecha_modificacion = di_fecha_modificacion,
	 @w_verificado         = di_verificado,
         @w_fecha_ver          = di_fecha_ver,
         @w_usuario_ver        = di_usuario_ver,
         @w_vigencia           = di_vigencia,
         @w_fecha_caducidad    = di_fecha_caducidad,
         @w_nombre_verif       = di_nombre_verif,
         @w_cargo_verif        = di_cargo_verif,
         @w_usuario_reg        = di_usuario_reg,
         @w_usuario_mod        = di_usuario_mod,
         @w_tipo_verif_incns   = di_tipo_verif_incns,
         @w_bancarizacion      = di_bancarizacion,
	 @w_pto_referencia     = di_referencia,
         @w_tipo_servicio      = di_tipo_servicio,	--ref25
         @w_cod_empresa        = di_empresa_servicio, 	--ref25
         @w_direc_planilla     = di_direc_planilla, 	--ref25
         @w_cod_rela_prop      = di_cod_rela_prop, 	--ref25
         @w_nom_propietario    = di_nom_propietario,	--ref25
	 @w_canton             = di_canton -- ref 30
  from cobis..cl_direccion
  where di_ente = @i_ente
  and di_direccion = @i_direccion

  if @@rowcount = 0
     begin
       /* 'No existe dato solicitado' */
       select @w_num = 101001
       goto mensaje_error
     end

  if @e_actmasivacli = 'N'	--ref34
     begin
       /* Si se quiere borrar todas las direcciones */
       if (select count(1) from cobis..cl_direccion where di_ente = @i_ente) = 1
          begin
            /* 'No se puede eliminar todas las direcciones' */
            select @w_num = 101053
            goto mensaje_error
          end

       /* es envio de correspondencia */
       if @w_envio_crp = 'S'
          begin
            /* 'NO SE PUEDE ELIMINAR LA DIRECCION DE ENVIO DE CORRESPONDENCIA' */
            select @w_num = 101274
            goto mensaje_error
          end

       /* Si esta asociada a una cuenta corriente  --FRM NOV/2009 */
       if exists (select 1 from cob_cuentas..cc_ctacte
                  where cc_cliente = @i_ente and cc_tipo_dir = 'D'
                  and cc_direccion_ec = @i_direccion and cc_estado not in ('C', 'Q'))
          begin
            /* 'NO SE PUEDE ELIMINAR UNA DIRECCION DE ENVIO DE ESTADO CUENTA' */
            select @w_num = 101273
            goto mensaje_error
          end

       --ref21
       /* Si esta asociada a una direccion de envio de estado de cuenta de tarjeta de credito --FRM NOV/2009 */
       if exists (select 1 from cl_dir_envio_tarj_cred
                  where dt_ente = @i_ente and dt_tipo_direc_envio in('D','T','O')
                  and dt_sec_direc_envio = @i_direccion and dt_estado = 'A')
          begin
            /* 'NO SE PUEDE ELIMINAR UNA DIRECCION DE ENVIO DE ESTADO CUENTA' */
            select @w_num = 101273
            goto mensaje_error
          end
       --ref21

       --ref25
       --Valida si la direccion tipo domicilio a eliminar tiene asociada un numero movil.
       if @w_subtipo = 'P' and @w_tipo = 'D'
          begin
            if exists(select 1 from cl_direccion_email where de_ente = @i_ente and de_tipo = 'M' and de_dir_domici = @i_direccion)
               begin
                 select @w_num = 101692
                 goto mensaje_error
               end
          end
       --ref25
     end

  /** secuencial de la transaccion de servicio **/
  if @i_no_cobis = 'S'
     begin
       exec @w_return = cobis..sp_gen_sec
	   @s_date 	 = @s_date,
           @o_secuencial = @s_ssn out

       if @w_return != 0
          begin
            /* 'Error en creacion de transaccion de servicio'*/
            select @w_num = 103005
            goto mensaje_error
          end
     end

  --ref31 Ini  Obtiene el canal de donde se realizo la eliminacion de la direccion
  if @i_envio_notifica = 'S' and @w_subtipo = 'P'
     begin
       if @w_fecha_reg > @w_fecha_crea_cli
	  begin
            if @i_producto = 2 and @i_canal <> 'VREFEREN'
               select @w_canal = 'MIS'
            else
               if @i_producto = 166 and exists(select a.valor from cl_catalogo a, cl_tabla b where b.tabla = 'cl_cbpmnac'
                                               and a.tabla = b.codigo and a.codigo = @i_canal)
                  select @w_canal = 'BPM'
               else
                  if @i_producto = 166 and exists(select a.valor from cl_catalogo a, cl_tabla b where b.tabla = 'cl_cfinnac'
                                                  and a.tabla = b.codigo and a.codigo = @i_canal)
                     select @w_canal = 'FORMINT'
                  else
                     if @i_canal = 'VREFEREN'
                        select @w_canal = @i_canal
                   --ref37
                     if @i_canal = 'ONB'
                        select @w_canal = @i_canal
                   --ref37 Fin
                     else
                        select @w_canal = 'OTROS'

            --Obtiene el servicio para la notificacion
     	    select @w_servicio = 'Actualizacion de Direccion ' + case when @w_tipo = 'D' then 'de Domicilio'
                                              	     when @w_tipo = 'T' then 'de Trabajo'
                                              	     else 'Otros'
                                         	 end
            select @w_serv_del_dir = @w_servicio
		  end
     end
  --ref31 Fin

  Begin Tran

    /* Eliminacion de la direccion */
    delete cl_direccion
    where di_ente = @i_ente
    and di_direccion = @i_direccion

    if @@error != 0
       begin
         /* 'Error en eliminacion de direccion' */
         select @w_num = 107007
         goto mensaje_error
       end

    /** Transaccion servicios - cl_direccion */
    insert into cobis..ts_direccion (
     secuencial, tipo_transaccion, cod_alterno, clase, fecha, usuario, terminal, srv, lsrv, origen, rol,
     ente, direccion, descripcion, sector, zona, parroquia, ciudad, tipo, oficina,
     envio_crp, canton,parroquia_ciu, observacion, verificado, fecha_ver, usuario_ver, vigencia, fecha_caducidad, --ref 30
     nombre_verif, cargo_verif, tipo_verif_incns, bancarizacion, referencia,
     tipo_servicio, empresa_servicio, direc_planilla, cod_rela_prop, nom_propietario, canal)	--ref31	--ref25
    values(@s_ssn, @t_trn, @i_direccion, 'B', @w_today, @s_user, @s_term, @s_srv, @s_lsrv, @i_producto, @s_rol,
     @i_ente, @i_direccion, @w_descripcion, @w_sector, @w_zona, @w_parroquia, @w_ciudad, @w_tipo, @w_oficina,
     @w_envio_crp, @w_canton,@w_parroquia_ciu, @w_observacion, @w_verificado, @w_fecha_ver, @w_usuario_ver, @w_vigencia, @w_fecha_caducidad, --ref 30
     @w_nombre_verif, @w_cargo_verif, @w_tipo_verif_incns, @w_bancarizacion, @w_pto_referencia,
     @w_tipo_servicio, @w_cod_empresa, @w_direc_planilla, @w_cod_rela_prop, @w_nom_propietario, @w_canal)   --ref31  --ref25

    if @@error != 0
       begin
	 /* 'Error en creacion de transaccion de servicio' */
         select @w_num = 103005
         goto mensaje_error
       end

    --ref21
    --Inserta registro en tabla log direcciones estado de cuenta tc --FRM Nov/2009
    insert into cl_log_dir_envio_ec(ld_fecha,ld_secuencial,ld_ente,ld_tipo_accion,ld_usuario,ld_oficina_usu,ld_tipo_dir_ant,ld_tipo_dir_act,
      ld_sec_direc_ant,ld_sec_direc_act,ld_cuenta_tarjeta,ld_valor_anterior,ld_valor_actual,ld_estado)   --I = ingresado  P= procesado
    values(@w_today,@s_ssn,@i_ente,'E',@s_user,@s_ofi,@w_tipo,@w_tipo,
      @i_direccion,@i_direccion,NULL,@w_descripcion,@w_descripcion,'I')
    --ref21

    if @@error != 0
       begin
         /* 'Error en creacion log direccion envio estado de cuenta' */
         select @w_num = 101613
         goto mensaje_error
       end

    /** Historico de direcciones/telefonos **/
    select @w_secuencial_hd = isnull(max(hd_secuencial),0) + 1
    from cobis_his..cl_direccion_his
    where hd_ente = @i_ente

    insert into cobis_his..cl_direccion_his (
      hd_ente, hd_secuencial, hd_direccion, hd_descripcion,
      hd_parroquia, hd_ciudad, hd_tipo, hd_telefono, hd_sector, hd_zona, hd_oficina,
      hd_fecha_registro, hd_fecha_modificacion, hd_vigencia, hd_verificado,
      hd_envio_crp, hd_parroquia_ciu, hd_fecha_ver, hd_observacion, hd_usuario_ver,
      hd_fecha_caducidad, hd_nombre_verif, hd_cargo_verif, hd_usuario_reg, hd_usuario_mod,
      hd_producto_elim, hd_usuario_elim, hd_fecha_elimina, hd_tipo_verif_incns,
      hd_bancarizacion, hd_referencia,
      hd_tipo_servicio, hd_empresa_servicio, hd_direc_planilla, hd_cod_rela_prop, hd_nom_propietario,hd_canton) --ref25	--ref 30
    values(@i_ente, @w_secuencial_hd, @i_direccion, @w_descripcion,
      @w_parroquia, @w_ciudad, @w_tipo, null, @w_sector, @w_zona, @w_oficina,
      @w_fecha_registro, @w_fecha_modificacion, @w_vigencia, @w_verificado,
      @w_envio_crp, @w_parroquia_ciu, @w_fecha_ver, @w_observacion, @w_usuario_ver,
      @w_fecha_caducidad, @w_nombre_verif, @w_cargo_verif, @w_usuario_reg, @w_usuario_mod,
      @i_producto, @s_user, @w_today, @w_tipo_verif_incns, @w_bancarizacion, @w_pto_referencia,
      @w_tipo_servicio, @w_cod_empresa, @w_direc_planilla, @w_cod_rela_prop, @w_nom_propietario, @w_canton)	--ref25	--ref 30

    if @@error != 0
       begin
         /* 'Error en eliminacion de direccion' */
         select @w_num = 107007
         goto mensaje_error
       end

    insert into cobis_his..cl_telefono_his (
      ht_ente, ht_secuencial_hd, ht_direccion, ht_secuencial,
      ht_valor, ht_tipo_telefono, ht_extension, ht_comentario,
      ht_producto, ht_usuario, ht_fecha_elimina, ht_pertenece)
    select te_ente, @w_secuencial_hd, te_direccion, te_secuencial,
      te_valor, te_tipo_telefono, te_extension, te_comentario,
      @i_producto, @s_user, @w_today, te_pertenece
    from cobis..cl_telefono
    where te_ente = @i_ente
    and te_direccion = @i_direccion

    if @@error != 0
       begin
         /* 'Error en eliminacion de direccion' */
         select @w_num = 107007
         goto mensaje_error
       end
    /** Eliminacion de todos los telefonos de la direccion **/
    /*Ref 30 Lineamientos de Q.A.*/
    set @w_contini = 0
    set @w_contini = (select count(te_secuencial) from cobis..cl_telefono
		      where te_ente = @i_ente and te_direccion = @i_direccion)
    set @w_contfin = 0
    --ref31 Ini
    if @i_envio_notifica = 'S' and @w_subtipo = 'P'
       begin
         if @w_fecha_reg > @w_fecha_crea_cli
            begin
              --Envia Notificacion al cliente por la eliminacion de direccion

      	      exec @w_return = cobis..sp_notif_cli_mod_dir
		@i_producto 	   = @i_producto,
		@i_ente     	   = @i_ente,
		@i_canalmod        = @i_canal,
		@i_oficina	   = @s_ofi,
		@i_envio_notifica  = @i_envio_notifica,	  --Cuando sean actualizaciones masivas se debe enviar el valor "N"
		@i_idcliente       = @w_idcliente,
		@i_today           = @w_today,
		@i_nombrecli 	   = @w_nombrecli,
	 	@i_p_apellido 	   = @w_p_apellido,
	 	@i_s_apellido 	   = @w_s_apellido,
		@i_servicio        = @w_servicio,
		@i_mail		   = @w_mail,
		@i_telefono	   = '0'
				,@o_medio 			= @w_medio out, --ref36
				@o_nombrecli 		= @w_nombrecliente out, --ref36
				@o_fecha 			= @w_fecha out, --ref36
				@o_hora 			= @w_hora out, --ref36
				@o_idcli_enm 		= @w_idcli_enm out, --ref36
				@o_nemonico 		= @w_nemonico out --ref36

						if @w_return != 0
					 begin
					   --'Error en Notificacion al Cliente por Actualizacion de Datos'
					   select @w_num = @w_return
					   goto mensaje_error
					 end
					--ref36 Inicio
					--Retorna campos para envio de notificacion
					select @w_medio,
						@w_nombrecliente,
						@w_fecha,
						@w_hora,
						@w_idcli_enm,
						@w_servicio,
						@w_mail,
						@w_nemonico,
						@w_contini,
						@w_celular
					--ref36 Fin
			end
       end
    --ref31 Fin

    --      while (1 = 1)
    /*Ref 30 Lineamientos de Q.A.*/
    while (@w_contfin < @w_contini)
    begin
      set rowcount 1

      select @w_telefono = te_secuencial
      from cobis..cl_telefono
      where te_ente = @i_ente
      and te_direccion = @i_direccion

      if @@rowcount = 0
         begin
           set rowcount 0
           break
         end

      set rowcount 0

      exec @w_return = cobis..sp_telefono
	 @s_ssn         = @s_ssn,
	 @s_user        = @s_user,
	 @s_term        = @s_term,
	 @s_date        = @s_date,
	 @s_srv         = @s_srv,
	 @s_lsrv        = @s_lsrv,
	 @s_ofi         = @s_ofi,
	 @s_rol         = @s_rol,
	 @s_org_err     = @s_org_err,
	 @s_error       = @s_error,
	 @s_sev         = @s_sev,
	 @s_msg         = @s_msg,
	 @s_org         = @s_org,
	 @t_debug       = @t_debug,
	 @t_file        = @t_file,
	 @t_from        = @t_from,
	 @t_trn         = 148,
	 @p_alterno     = @w_telefono,
	 @i_operacion   = 'D',
         @i_no_cobis    = @i_no_cobis,
         @i_mensaje     = @i_mensaje,
         @i_producto    = @i_producto,
	 @i_ente        = @i_ente,
	 @i_direccion   = @i_direccion,
	 @i_secuencial  = @w_telefono,
	 @i_envio_notifica = @i_envio_notifica,	--ref31
	 @i_canal       = @i_canal		--ref31

      set @w_contfin = (@w_contfin + 1)--Ref 30 Lineamientos de Q.A.

      if @w_return != 0
         begin
           /* 'Error en actualizacion de direccion' */
           select @w_num = 105034
           goto mensaje_error
         end
    end
  commit tran

return 0
end
else
begin
  /*  'No corresponde codigo de transaccion' */
  select @w_num = 151051
  goto mensaje_error
end
end

/** Delete con validaciones a tablas temporales**/
if @i_operacion = 'E'
begin
if @t_trn = 1226
begin
   if exists(select 1 from cobis..cl_producto where pd_producto = @i_producto)
      select @w_codigo = null
   else
   begin
      /* 'No existe producto' */
      select @w_num = 101032
      goto mensaje_error
   end

   /*  Campos para transaccion de  servicios */
   select @w_descripcion     = di_descripcion,
	  @w_tipo            = di_tipo,
	  @w_parroquia       = di_parroquia,
	  @w_ciudad	     = di_ciudad,
	  @w_sector          = di_sector,
	  @w_zona	     = di_zona,
	  @w_oficina         = di_oficina,
          @w_envio_crp       = di_envio_crp,
          @w_parroquia_ciu   = di_parroquia_ciu,
          @w_observacion     = di_observacion,
	  @w_verificado      = di_verificado,
          @w_fecha_ver       = di_fecha_ver,
          @w_usuario_ver     = di_usuario_ver,
          @w_vigencia        = di_vigencia,
          @w_fecha_caducidad = di_fecha_caducidad,
          @w_nombre_verif    = di_nombre_verif,
          @w_cargo_verif     = di_cargo_verif,
          @w_tipo_verif_incns= di_tipo_verif_incns,
          @w_bancarizacion   = di_bancarizacion,
	  @w_pto_referencia  = di_referencia,
	  @w_canton          = di_canton  --ref 30
     from  cobis..cl_direccion
     where  di_ente = @i_ente
     and  di_direccion = @i_direccion

   if @@rowcount = 0
   begin
      /* 'No existe dato solicitado' */
      select @w_num = 101001
      goto mensaje_error
   end

   /* Si se quiere borrar todas las direcciones */
   if (select count(1) from cobis..cl_direccion_tmp where di_ente = @i_ente and di_estado <> 'E') = 0
   begin
      /* 'No se puede eliminar todas las direcciones' */
      select @w_num = 101053
      goto mensaje_error
   end

   /* es envio de correspondencia */
   if @w_envio_crp = 'S' and not exists(select 1 from cobis..cl_direccion_tmp where di_ente = @i_ente and di_envio_crp = 'S' and di_estado <> 'E')
   begin
      /* 'NO SE PUEDE ELIMINAR LA DIRECCION DE ENVIO DE CORRESPONDENCIA' */
      select @w_num = 101274
      goto mensaje_error
   end

   /* Si esta asociada a una cuenta */
   if exists (select 1 from cobis..cl_dir_est_cta_tmp where cc_cliente = @i_ente and cc_cliente_ec = @i_ente and cc_tipo_dir = 'D'
              and cc_direccion_ec = @i_direccion and cc_estado not in ('C', 'Q'))
   begin
      /* 'NO SE PUEDE ELIMINAR UNA DIRECCION DE ENVIO DE ESTADO CUENTA' */
      select @w_num = 101273
      goto mensaje_error
   end

   /** secuencial de la transaccion de servicio **/
   if @i_no_cobis = 'S'
   begin
      exec @w_return = cobis..sp_gen_sec
	   @s_date 	 = @s_date,
           @o_secuencial = @s_ssn out

      if @w_return != 0
      begin
         /* 'Error en creacion de transaccion de servicio'*/
         select @w_num = 103005
         goto mensaje_error
      end
   end

   Begin Tran
      /** Eliminacion de todos los telefonos de la direccion **/
	  /*Ref 30 Fin Lineamientos de Q.A.*/
	  set @w_contini = 0
	  set @w_contfin = 0
		set @w_contini = (	select	count(te_secuencial)
							from	cobis..cl_telefono
							where	te_ente = @i_ente and te_direccion = @i_direccion)

		while (@w_contfin < @w_contini)
      --while (1 = 1)
	  /*Ref 30 Fin Lineamientos de Q.A.*/
      begin
         set rowcount 1

         select @w_telefono = te_secuencial from cobis..cl_telefono where te_ente = @i_ente and te_direccion = @i_direccion

         if @@rowcount = 0
         begin
            set rowcount 0
            break
         end

         select @w_aux_codalt = (@i_direccion * 100) + @w_telefono
         set rowcount 0

	 exec @w_return = cobis..sp_telefono
	      @s_ssn         = @s_ssn,
	      @s_user        = @s_user,
	      @s_term        = @s_term,
	      @s_date        = @s_date,
	      @s_srv         = @s_srv,
	      @s_lsrv        = @s_lsrv,
	      @s_ofi         = @s_ofi,
	      @s_rol         = @s_rol,
	      @s_org_err     = @s_org_err,
	      @s_error       = @s_error,
	      @s_sev         = @s_sev,
	      @s_msg         = @s_msg,
	      @s_org         = @s_org,
	      @t_debug       = @t_debug,
	      @t_file        = @t_file,
	      @t_from        = @t_from,
	      @t_trn         = 148,
	      @p_alterno     = @w_aux_codalt,
	      @i_operacion   = 'D',
              @i_no_cobis    = @i_no_cobis,
              @i_mensaje     = @i_mensaje,
              @i_producto    = @i_producto,
	      @i_ente        = @i_ente,
	      @i_direccion   = @i_direccion,
	      @i_secuencial  = @w_telefono,
	      @i_envio_notifica = 'N'	--ref31


		set @w_contfin = (@w_contfin + 1)--Ref 30 Lineamientos de Q.A.
	 if @w_return != 0
         begin
            /* 'Error en actualizacion de direccion' */
            select @w_num = @w_return
            goto mensaje_error
         end
      end

      /* Eliminacion de la direccion */
      delete cl_direccion
	 where di_ente = @i_ente
	 and di_direccion = @i_direccion

      if @@error != 0
      begin
	 /* 'Error en eliminacion de direccion' */
         select @w_num = 107007
         goto mensaje_error
      end

      /** Transaccion servicios - cl_direccion */
      insert into cobis..ts_direccion (secuencial, tipo_transaccion, cod_alterno, clase, fecha, usuario, terminal, srv, lsrv, origen, rol,
       ente, direccion, descripcion, sector, zona, parroquia, ciudad, tipo, oficina, envio_crp, parroquia_ciu, observacion,
       verificado, fecha_ver, usuario_ver, vigencia, fecha_caducidad, nombre_verif, cargo_verif, tipo_verif_incns, bancarizacion, referencia)
       values(@s_ssn, @t_trn, @i_direccion, 'B', @w_today, @s_user, @s_term, @s_srv, @s_lsrv, @i_producto, @s_rol,
        @i_ente, @i_direccion, @w_descripcion, @w_sector, @w_zona, @w_parroquia, @w_ciudad, @w_tipo, @w_oficina, @w_envio_crp, @w_parroquia_ciu,
        @w_observacion, @w_verificado, @w_fecha_ver, @w_usuario_ver, @w_vigencia, @w_fecha_caducidad, @w_nombre_verif, @w_cargo_verif,
        @w_tipo_verif_incns, @w_bancarizacion, @w_pto_referencia)

      if @@error != 0
      begin
	  /* 'Error en creacion de transaccion de servicio' */
         select @w_num = 103005
         goto mensaje_error
      end

   commit tran

   return 0
end
else
begin
   /*  'No corresponde codigo de transaccion' */
   select @w_num = 151051
   goto mensaje_error
end
end

return 0

/** enviar el mensaje de error **/
mensaje_error:
if @i_mensaje = 'S'
begin
   exec cobis..sp_cerror
	@t_debug    = @t_debug,
	@t_file     = @t_file,
	@t_from     = @w_sp_name,
	@i_num      = @w_num
   return 1
end
else
begin
   exec cobis..sp_msj_error
	@t_debug    = @t_debug,
	@t_file     = @t_file,
	@t_from     = @w_sp_name,
	@i_numero   = @w_num,
        @o_mensaje  = @o_msj_error out
   return @w_num
end

go

/*--Ref 30 Ini Lineamientos de Q.A.*/
if exists (select 1 from sysobjects where name = 'sp_direccion_dml' and type = 'P')
   begin
     PRINT '== CREATE PROCEDURE sp_direccion_dml *OK* =='
   end
else
   begin
     PRINT '<<< CREATE PROCEDURE sp_direccion_dml -- ERROR -- >>>'
   end
go
/*--Ref 30 Fin Lineamiento de Q.A.*/

/* ========================================================================= */
--<REF 33
--Permiso de ejecucion para el usuario apl_dbconnector_hpact
grant execute
	on sp_direccion_dml
	to apl_dbconnector_hpact
go

--REF 35>

--Permisos para usuario apl_osb_hpact
--grant execute on sp_direccion_email to apl_osb_hpac
--grant execute on sp_direccion_email to apl_osb_hpdes
--go

--Permisos para usuario apl_sensoribk_sybase
--grant execute on sp_direccion_email to apl_sensoribk_sybase
--go

--grant execute on sp_direccion_email to apl_onboarding_hpact
--go
