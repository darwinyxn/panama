# Generacion estructural de casos: `sp_tr_deposito_rc`

## Resumen de plan de generacion
- `tipo_analisis`: estructural (BVA + cobertura de ramas + fraccion de centavo)
- `archivo_sp`: `insumos/sp_tr_deposito_rc/sp/trdep_rc.sp`
- `analysis_file`: `insumos/sp_tr_deposito_rc/analisis/analisis_sp_tr_deposito_rc.md` (inventario estructural, complejidad y estimacion)
- `casos_finales_estimados`: 148
- `complejidad_final`: CRITICA
- `objetivo_casos`: 89. Calculo: 148 x 50% = 74; complejidad CRITICA suma 10 puntos porcentuales: 148 x 60% = 88.8, redondeado a 89.
- `objetivo_casos_lote`: 25 (primer lote por regla operativa)
- `estado`: BLOQUEADO_POR_INCONSISTENCIAS
- No se publican casos ejecutables hasta resolver hallazgos de contrato y precision monetaria.

## Parametros base de ejecucion
- Base: `cob_cuentas`
- Procedimiento: `dbo.sp_tr_deposito_rc`
- Cuenta candidata leida en modo solo lectura: `0000022767`, estado `A`, cuenta interna `144`, origen `2  `.
- Parametros de contexto sugeridos para el caso base: `@i_canal='VEN'`, `@s_org='U'`, `@t_corr='N'`, `@t_trn=3040`, `@i_mon=1`, `@i_efe=1.00`, `@i_loc=0.00`, `@i_autoriza='N'`.
- Umbrales leidos en solo lectura de `cobis..cl_parametro` para `pa_producto='CTE'`: `MDDP=10000.0000`, `MMDP=0.0000`.
- Candidato cuenta restringida leido en solo lectura: `0005347528`, estado `T`.
- `@i_cta` tiene tipo de usuario `cuenta`, longitud 24 verificada con `cob_cuentas..systypes`.
- Los valores anteriores son evidencia/referencias y no autorizan la ejecucion de depositos.

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
    @s_user = 'qa_estructural',
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
- El fuente contiene la firma completa de `dbo.sp_tr_deposito_rc`, su cuerpo activo y las expresiones monetarias identificadas.
- La cuenta de referencia y los umbrales MDDP/MMDP se obtuvieron con consultas `SELECT` de solo lectura; no se ejecutaron casos ni se alteraron datos.
- Frontera monetaria literal del padre, en la condicion que comienza en la linea del SP `1027`: `@w_maximo_p <= (@i_efe + @i_loc) OR @w_minimo_p >= (@i_efe + @i_loc)`, y adicionalmente `@w_moneda_caja = 0`. El rechazo retorna `311819` si las otras condiciones de activacion tambien aplican.
- Otras expresiones estructurales en el padre: `@i_efe > 0 AND @t_corr = 'N'` antes de llamar a verificacion de deposito; para CNB, `@w_utilizado + @i_efe > @w_cupo_cli` retorna `39007`.
- No se encontro formula `ROUND`, truncamiento ni conversion monetaria con regla de escala/redondeo en el cuerpo padre. `sp_convierte_valor` y el registro monetario se delegan a dependencias.
- Tablas/columnas directamente referenciadas por el padre se revisaron contra el fuente. No se declara un diccionario de datos para efectos o tablas internas de SP hijos.

### Hallazgos del preflight
1. **Contrato de persistencia ausente para el posting delegado.** El padre invoca `cob_cuentas..sp_tr_depo2_local_remoto_rc` en las rutas local/submitida, pero el analisis solo documenta retornos y OUTs. No hay evidencia declarada de las tablas/columnas persistentes que permitan una consulta post-ejecucion completa para verificar las rutas de deposito y los efectos de sus errores.
2. **Contrato de precision monetaria ausente.** La conversion se delega a `cob_cuentas..sp_convierte_valor`; calculo de cupo y verificacion se delegan a `cobis..sp_verificacion_deposito_rc`. No se dispone de su codigo/contrato de redondeo, escala, salidas garantizadas ni tablas de soporte. Por tanto, no se puede afirmar el resultado de valores fraccionarios como `0.0049`, `0.005` o `0.0051`, ni construir validaciones de cuadre basadas solo en el padre.
3. **Ramas dependientes de estados/datos internos sin respaldo suficiente.** El cierre de cuenta por inhabilitacion SBS y la actualizacion de consulta automatica dependen de SP hijos/OUTs y de estado previo especifico. El analisis resume el contrato, pero no aporta evidencia de los datos requeridos ni la persistencia completa para postvalidar esos escenarios.
4. **Estimaciones no equivalen a un catalogo de IDs estructurales ejecutables.** El inventario proporciona ramas `RAMA-XXX` y conteos globales, pero no define IDs `AEST-RAMA`, `AEST-BVA` y `AEST-CENT` con trazabilidad caso a caso. Esta matriz debe producirse cuando el contrato pase.

### Correccion propuesta
- Aportar el codigo fuente o contratos aprobados de `sp_tr_depo2_local_remoto_rc`, `sp_convierte_valor` y `sp_verificacion_deposito_rc`, incluyendo tablas/columnas persistentes, escala, redondeo y resultados observables.
- Definir precondiciones/datos controlados para cada retorno de esos SP y una estrategia aislada para los estados de cuenta usados en pruebas estructurales.
- Completar el catalogo de IDs estructurales y volver a ejecutar preflight. El lote inicial sugerido es `TC-001..TC-025`.

## Control de Cobertura
- `objetivo_casos`: 89
- `objetivo_casos_lote`: 25
- `casos_generados`: 0
- `porcentaje_cumplimiento`: 0%
- `brecha`: 89
- `estado_tolerancia`: FUERA_RANGO (generacion detenida por bloqueo del contrato)
- `rango_generado`: ninguno
- `siguiente_rango_sugerido`: TC-001..TC-025, despues de resolver los hallazgos
- `ids_cubiertos`: ninguno; no se publicaron casos
- `ids_justificados`: no aplica, pendiente de aprobar la matriz AEST; no se fusionaron ramas ni fronteras
- `nota_depuracion`: no se generaron casos ejecutables; aunque se verificaron fronteras MDDP/MMDP, no se atribuyen efectos ni precision a dependencias sin contrato y no se inventan consultas post-ejecucion
- `estado_validacion_contrato`: BLOQUEADO_POR_INCONSISTENCIAS
- `hallazgos_preflight`: posting, conversion/rounding y valores OUT de cupo dependen de contratos no adjuntos; faltan IDs AEST trazables
- `columnas_verificadas`: columnas expresamente referidas por el padre; ninguna columna de posting hijo declarada/verificada
- `parametros_verificados`: firma y tipos/defaults contrastados con el fuente; `@i_cta cuenta` longitud 24 verificada por metadata
