# Generacion funcional de casos: `sp_tr_deposito_rc`

## Resumen de plan de generacion
- `tipo_analisis`: funcional
- `archivo_sp`: `insumos/sp_tr_deposito_rc/sp/trdep_rc.sp`
- `analysis_file`: `insumos/sp_tr_deposito_rc/analisis/analisis_sp_tr_deposito_rc.md` (inventario estructural disponible; contiene reglas funcionales y contratos resumidos)
- `objetivo_casos`: 59. Calculo: 148 casos finales estimados x 50% = 74; por complejidad CRITICA se restan 10 puntos porcentuales: 148 x 40% = 59.2, redondeado a 59.
- `objetivo_casos_lote`: 25 (primer lote, por regla de lotes)
- `estado`: BLOQUEADO_POR_INCONSISTENCIAS
- No se publican casos ejecutables hasta resolver los hallazgos del preflight.

## Parametros base de ejecucion
- Base: `cob_cuentas`
- Procedimiento: `dbo.sp_tr_deposito_rc`
- Cuenta candidata consultada en solo lectura: `0000022767` (estado `A`, cuenta interna `144`, origen `2  `).
- `@i_canal='VEN'`, `@s_org='U'`, `@t_corr='N'`, `@t_trn=3040`, `@i_mon=1`, `@i_efe=1.00`, `@i_loc=0.00` son valores de referencia controlados, no una recomendacion para ejecutar mientras el estado sea bloqueado.
- La consulta de solo lectura a `cobis..cl_parametro` devolvio `ALCNB` con `pa_char='N'`; no se modifico este parametro.
- `@i_cta` usa el tipo definido por usuario `cuenta`, verificado en `cob_cuentas..systypes` con longitud 24.

## Plantilla de ejecucion del SP
Plantilla completa de referencia. No ejecutar: el preflight esta bloqueado.

```sql
DECLARE @v_o_nombre varchar(30),
        @v_o_impuesto money,
        @v_o_neto money,
        @v_o_ssn int,
        @v_o_consulta int,
        @v_o_novedad_sbs char(1),
        @v_o_msg_error varchar(132),
        @v_o_fecha_contable varchar(10),
        @v_o_servicio_not varchar(5),
        @v_o_cod_ente varchar(20),
        @v_o_celular varchar(10),
        @v_o_correo varchar(64),
        @v_o_valor varchar(11),
        @v_o_valor1 varchar(11),
        @v_o_prod_deb char(3),
        @v_o_cta_lat char(3)

EXEC cob_cuentas..sp_tr_deposito_rc
    @s_ssn = 900001,
    @s_srv = 'QA-SRV',
    @s_lsrv = 'QA-LSRV',
    @s_user = 'qa_funcional',
    @s_sesn = NULL,
    @s_term = 'QA-TERM',
    @s_date = '2026-10-02',
    @s_ofi = 1,
    @s_rol = 1,
    @s_org_err = NULL,
    @s_error = NULL,
    @s_sev = NULL,
    @s_msg = NULL,
    @s_org = 'U',
    @t_corr = 'N',
    @t_ssn_corr = NULL,
    @t_debug = 'N',
    @t_file = NULL,
    @t_from = NULL,
    @t_rty = 'N',
    @t_trn = 3040,
    @p_lssn = NULL,
    @p_rssn = NULL,
    @p_rssn_corr = NULL,
    @p_slddisp = NULL,
    @p_sldcont = NULL,
    @p_nombre = NULL,
    @p_envio = 'N',
    @p_rpta = 'N',
    @i_cta = '0000022767',
    @i_efe = 1.00,
    @i_prop = 0,
    @i_loc = 0,
    @i_plaz = 0,
    @i_mon = 1,
    @i_sp = 'N',
    @i_tsn = NULL,
    @i_autoriza = 'N',
    @i_codigo = NULL,
    @i_empresa = NULL,
    @i_des_cli = NULL,
    @i_factura = NULL,
    @i_cant_chq = NULL,
    @i_ubi = NULL,
    @o_nombre = @v_o_nombre OUTPUT,
    @o_impuesto = @v_o_impuesto OUTPUT,
    @o_neto = @v_o_neto OUTPUT,
    @o_ssn = @v_o_ssn OUTPUT,
    @o_consulta = @v_o_consulta OUTPUT,
    @i_ssn = NULL,
    @i_date_off = NULL,
    @i_canal = 'VEN',
    @i_aplcobis = 'S',
    @i_ruta_transito = NULL,
    @i_nomb_dep = NULL,
    @e_cds = NULL,
    @o_novedad_sbs = @v_o_novedad_sbs OUTPUT,
    @o_msg_error = @v_o_msg_error OUTPUT,
    @o_fecha_contable = @v_o_fecha_contable OUTPUT,
    @i_iden_dep = NULL,
    @i_debito = NULL,
    @i_val_consep = NULL,
    @i_denominaciones = '',
    @e_cod_trx = 0,
    @e_verde = 'N',
    @e_uuid = '',
    @o_servicio_not = @v_o_servicio_not OUTPUT,
    @o_cod_ente = @v_o_cod_ente OUTPUT,
    @o_celular = @v_o_celular OUTPUT,
    @o_correo = @v_o_correo OUTPUT,
    @o_valor = @v_o_valor OUTPUT,
    @o_valor1 = @v_o_valor1 OUTPUT,
    @o_prod_deb = @v_o_prod_deb OUTPUT,
    @o_cta_lat = @v_o_cta_lat OUTPUT
```

## Validacion de contrato del SP
**Estado: BLOQUEADO_POR_INCONSISTENCIAS**

### Elementos verificados
- Procedimiento: `dbo.sp_tr_deposito_rc`; base declarada y usada: `cob_cuentas`.
- Firma: parametros, tipos SQL, defaults y direcciones leidos del `CREATE PROC` completo. `@i_cta` es `cuenta`; su longitud 24 se verifico mediante `SELECT name, length, type FROM cob_cuentas..systypes WHERE name = 'cuenta'`.
- Tablas y columnas del SP padre: se contrastaron las referencias activas con el fuente. Para cuentas aparecen, entre otras, `cc_ctacte.cc_cta_banco`, `cc_ctacte.cc_ctacte`, `cc_ctacte.cc_estado`, `cc_ctacte.cc_origen` y `cc_ctacte.cc_filial`; el cierre SBS escribe `cc_estado`, `dp_estado_ser`, columnas `hc_*` y columnas de `cc_tscierre_cta` explicitadas en el SP.
- No hay diccionario de datos declarado para las tablas internas de los procedimientos hijos.
- Evidencia de solo lectura: se obtuvieron candidatos de `cc_ctacte` para estados `A` y `D`, y el valor actual de `ALCNB` (`N`). No se ejecutaron TCs ni se mutaron datos.

### Hallazgos del preflight
1. **Falta contrato verificable de persistencia para el deposito exitoso.** En `insumos/sp_tr_deposito_rc/sp/trdep_rc.sp`, el flujo local delega el registro a `cob_cuentas..sp_tr_depo2_local_remoto_rc` (invocaciones en las ramas local y submitida). El analisis, seccion `CONTRATO DE LIBRERIA POR SP HIJO`, solo especifica retornos/OUTs genericos; no declara las tablas/columnas insertadas o actualizadas. No es posible construir la validacion SQL post-ejecucion completa ni confirmar el efecto esperado en BD sin inventar el esquema.
2. **Falta contrato de origen de los valores de cupo.** `cobis..sp_verificacion_deposito_rc` llena `@w_cupo_cli` y `@w_utilizado`, usados por la regla CNB y el rechazo `39007`; el analisis registra el contrato como valores OUT, pero no respalda su dominio, origen ni precondiciones de datos. No se puede seleccionar una condicion CNB ejecutable y trazable para los escenarios de cupo a partir de las fuentes proporcionadas.
3. **La condicion de canal disponible no permite cubrir el camino CNB ordinario en el estado consultado.** `ALCNB` tiene valor actual `N`, que retorna `300003178` para CNB cuando `@s_user != 'cnb001'`. No se cambia configuracion durante la generacion. El analisis debe indicar si el entorno de pruebas ofrece una configuracion aislada con `ALCNB='A'` o un mecanismo de simulacion autorizado.

### Correccion propuesta
- Incorporar al analisis o declarar un diccionario verificado con el contrato de `sp_tr_depo2_local_remoto_rc`: tablas/columnas afectadas por deposito, claves para consultar el movimiento y efectos esperados por codigo de transaccion.
- Documentar el contrato de `sp_verificacion_deposito_rc`: precondiciones para producir `@w_cupo_cli`/`@w_utilizado`, valores candidatos y mecanismo permitido para simular cupo suficiente/excedido.
- Definir como se habilita de forma aislada el camino CNB positivo para pruebas sin cambiar datos de produccion.
- Repetir preflight y generar el primer lote `TC-001..TC-025` cuando esas evidencias esten disponibles.

## Control de Cobertura
- `objetivo_casos`: 59
- `objetivo_casos_lote`: 25
- `casos_generados`: 0
- `porcentaje_cumplimiento`: 0%
- `brecha`: 59
- `estado_tolerancia`: FUERA_RANGO (generacion detenida por bloqueo de contrato)
- `rango_generado`: ninguno
- `siguiente_rango_sugerido`: TC-001..TC-025, despues de resolver los hallazgos
- `ids_cubiertos`: ninguno; no se publicaron casos
- `ids_justificados`: elementos funcionales del analisis pendientes por bloqueo de contrato; trazabilidad AFUN no iniciada
- `nota_depuracion`: no se generaron casos ejecutables ni se asignaron IDs AFUN sin poder verificar el contrato persistente de las dependencias críticas
- `estado_validacion_contrato`: BLOQUEADO_POR_INCONSISTENCIAS
- `hallazgos_preflight`: falta esquema/efecto persistente del SP de contabilizacion; falta contrato verificable de valores OUT del SP de cupo; `ALCNB` consultado en estado `N`
- `columnas_verificadas`: referencias del SP padre enumeradas en Validacion de contrato del SP; sin columnas confirmadas del SP hijo de contabilizacion
- `parametros_verificados`: firma completa y tipos/defaults contrastados con el fuente; `@i_cta cuenta` longitud 24 verificada con metadata