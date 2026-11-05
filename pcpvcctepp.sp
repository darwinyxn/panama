/********************************************************************************/
/* Archivo:            pcpvcctepp.sp                                            */
/* Motor de Base:      SYBASE                                                   */
/* Base de datos:      cob_pagos                                                */
/* Servidor:           HP-ACT                                                   */
/* Aplicacion:         Recaudaciones                                            */
/* Stored procedure:   pa_cc_cval_catcctecnb                                    */
/* Procesamiento:      OLTP                                                     */
/* Ult.ControlTarea:   CNBE-671                                                 */
/* Ult.Referencia:     REF 2                                                    */
/* Disenado por:       ADRIAN ABRIL                                             */
/* Fecha de escritura: 09/04/2026                                               */
/********************************************************************************/
/*                              IMPORTANTE                                      */
/*    Este programa es parte de los paquetes bancarios propiedad del            */
/*    "BANCO BOLIVARIANO".                                                      */
/*    Su uso no autorizado queda expresamente prohibido asi como                */
/*    cualquier alteracion o agregado hecho por alguno de sus usuarios          */
/*    sin el debido consentimiento por escrito de la Presidencia                */
/*    Ejecutiva del BANCO BOLIVARIANO o su representante.                       */
/********************************************************************************/
/*                              PROPOSITO                                       */
/*    Este programa valida las cuentas corrientes con categoria permitidas      */
/*             por el canal CNB.      					                        */										
/********************************************************************************/
/*                              MODIFICACIONES                                  */
/*  REF      FECHA           AUTOR               RAZON         TAREA            */
/*   1    Jul/07/2023   Richard Suarez Jacome  CNB-1699  Emision Inicial 	    */
/*   2    09/04/2026    ADRIAN ABRIL           CNBE-671  Validación cuenta ahorro*/
/********************************************************************************/
use cob_pagos
go
if exists(select 1 from sysobjects where name = 'pa_cc_cval_catcctecnb' and type = 'P')
	begin
		drop procedure dbo.pa_cc_cval_catcctecnb
		if exists(select 1 from sysobjects where name = 'pa_cc_cval_catcctecnb' and type = 'P')
			Select 999
			else
			Select 1
	end   
go

create procedure dbo.pa_cc_cval_catcctecnb
(
@e_cuenta         varchar(24),
@s_cuenta         varchar(24)  = '' out,
@s_msg	          varchar(150) = '' out
)
as 
begin 
declare @v_msg_error	 mensaje
	select @s_cuenta = cc_cta_banco
		    from cob_cuentas..cc_ctacte      
			where cc_cta_banco = @e_cuenta
			and cc_categoria in (select ca.codigo 
			                              from cobis..cl_catalogo ca 
										  inner join cobis..cl_tabla ta 
										  on ca.tabla = ta.codigo              
			where ta.tabla = 'cc_categoriactecnbpp')		
    if @@rowcount = 0 
    begin
        select @s_cuenta = ah_cta_banco 
        from cob_ahorros..ah_cuenta  
        where ah_cta_banco = @e_cuenta
        and ah_categoria  in (select ca.codigo 
                                        from cobis..cl_catalogo ca 
                                        inner join cobis..cl_tabla ta 
                                        on ca.tabla = ta.codigo              
        where ta.tabla = 'cc_categoriactecnbpp')	
        if @@rowcount = 0 
		begin
				exec cobis..sp_error @i_from='',@i_num=37507,--31004, 
			                        @i_raise=0,@o_msg= @v_msg_error out				
					if @@error <> 0 		
					begin
						return 1011
					end				         
			    select @s_msg=@v_msg_error
					return 31004 
		end
    end
return 0			  
end 
go
if exists(select 1 from sysobjects where name='pa_cc_cval_catcctecnb' and type = 'P')
	select 1
	else
	select 999
go