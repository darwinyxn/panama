# Casos de Prueba - SP `sp_tr_deposito_rc`

**Base de datos:** `cob_cuentas` (Sybase), con dependencias en `cob_remesas`, `cobis`, `db_biz_admempresa`, `cob_pagos` y `cob_sbancario`.
**Proposito:** Procesa la transaccion de deposito completo.

> **Diagnostico BD ejecutado 2026-10-06:**
> - La cuenta propuesta por el consolidado (`6000010`) no existe en `cob_cuentas..cc_ctacte` ni en el catalogo de cuentas especiales. Se sustituyo por la cuenta real `0000144029`.
> - `0000144029`: `cc_ctacte=11515`, `cc_estado='A'`, `cc_moneda=1`, cero bloqueos vigentes tipo `1` o `3`; catalogo `ad_emp_dep_especial` activo, empresa `2291`.
> - `DEPCUENTA`: `pa_val_booleano='N'` para empresa `2291`, producto `4`, servicio `REE`; valor por omision tambien `N`.
> - La apertura de caja de sesion no existia. Se agrego solo dentro de `exec-rollback`; los snapshots antes/despues confirmaron cero filas con la marca y ningun cambio persistente.
> - Confirmacion final: `sp_cerror` lanzo `ERROR: ESTA TRANSACCION DEBE HACERLA POR DEPOSITO ESPECIAL`; rollback confirmado, cero transacciones nuevas para la cuenta.

---

## CONVENCIONES

| Simbolo | Significado |
|---------|-------------|
| PRE | Preparacion y estado verificado antes de la ejecucion. |
| POST | Validacion posterior y limpieza inversa de la preparacion. |
| ERROR | Rechazo de negocio lanzado por `cobis..sp_cerror`. |
| CTE local | Ruta de deposito de cuenta corriente por canal `VEN`; no se alcanza en este caso porque la validacion especial retorna antes. |
| CNB | Rama de canal distinto a este caso; no aplica a TC01. |
| SUPUESTO_CONTROLADO | Apertura de caja ausente en BD, preparada de forma idempotente y confirmada solo dentro de rollback. |

---

## PARAMETROS DE SESION POR DEFECTO

| Parametro | Valor por defecto | Descripcion |
|-----------|-------------------|-------------|
| **@s_ssn** | `261006013` | Secuencial de sesion libre verificado; asignar uno libre en cada ejecucion real. El valor consolidado `100001` produjo colision. |
| **@s_srv** | `'SRV_CTE'` | Servidor origen de la transaccion. |
| **@s_lsrv** | `'SRV_CTE_LOC'` | Servidor local. |
| **@s_user** | `'CAJERO01'` | Usuario operador. |
| **@s_term** | `'CAJA01'` | Terminal de origen. |
| **@s_date** | `GETDATE()` | Fecha de transaccion, asignada antes del `EXEC` a `@s_date`. |
| **@s_ofi** | `100` | Oficina origen. |
| **@s_rol** | `1` | Rol de caja usado por la plantilla consolidada. |
| **@s_org** | `'U'` | Origen usuario; activa validacion de caja para canal `VEN`. |
| **@t_corr** | `'N'` | Deposito normal, no correccion. |
| **@t_trn** | `3040` | Transaccion de deposito estandar. |
| **@i_cta** | `'1234567'` | Cuenta base del consolidado; TC01 la reemplaza por una cuenta especial real. |
| **@i_efe** | `100.00` | Valor en efectivo. |
| **@i_loc** | `0.00` | Valor en cheque/local. |
| **@i_mon** | `1` | Moneda de la cuenta, USD. |
| **@i_canal** | `'VEN'` | Canal ventanilla. |
| **@i_aplcobis** | `'S'` | Habilita el mensaje de negocio COBIS. |
| **@i_autoriza** | `'N'` | Sin autorizacion de cupo. |
| **@i_sp** | `'N'` | Deposito normal; activa el control de cuenta especial. |

Parametros que varia TC01: `@i_cta`, `@s_ssn` y `@i_sp` (este ultimo se envia expresamente para hacer visible el discriminador).

### PRECONDICION COMUN DE SESION

TC01 requiere una apertura de caja que no existia al diagnosticar. La fila se prepara solo si falta la misma llave de negocio, usando la marca `QA06102026TC13`. Esta hipotesis fue confirmada con `exec-rollback` el 2026-10-06; el wrapper informo `rollback_confirmed=true`, `persistence_verified=true`, y cero filas antes/despues para la marca.

**PRE - Apertura idempotente de caja:**
```sql
DECLARE @w_caja_existe int
SELECT @w_caja_existe = COUNT(1)
FROM cob_remesas..re_caja
WHERE cj_oficina = 100 AND cj_rol = 1 AND cj_operador = 'CAJERO01'
  AND cj_producto = 'APE' AND cj_moneda = 1 AND cj_transaccion = 3015
  AND cj_ubicacion = 0
  AND cj_fecha_real = CONVERT(datetime, CONVERT(varchar(10), GETDATE(), 101))
IF @w_caja_existe = 0
BEGIN
    INSERT INTO cob_remesas..re_caja
        (cj_oficina, cj_rol, cj_operador, cj_producto, cj_moneda, cj_transaccion, cj_numero,
         cj_efectivo, cj_cheque, cj_chq_locales, cj_chq_ot_plaza, cj_otros, cj_interes,
         cj_ajuste_int, cj_ajuste_cap, cj_nodo, cj_tipo, cj_fecha, cj_causa, cj_fecha_real, cj_ubicacion)
    VALUES
        (100, 1, 'CAJERO01', 'APE', 1, 3015, 1,
         0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
         0.00, 0.00, 'SRV_CTE', 'L', GETDATE(), 'QA06102026TC13',
         CONVERT(datetime, CONVERT(varchar(10), GETDATE(), 101)), 0)
END
```

**POST - Inversa exacta de la apertura:**
```sql
DELETE FROM cob_remesas..re_caja
WHERE cj_oficina = 100 AND cj_rol = 1 AND cj_operador = 'CAJERO01'
  AND cj_producto = 'APE' AND cj_moneda = 1 AND cj_transaccion = 3015
  AND cj_ubicacion = 0
  AND cj_fecha_real = CONVERT(datetime, CONVERT(varchar(10), GETDATE(), 101))
  AND cj_causa = 'QA06102026TC13'
```

La condicion de borrado exige la marca exclusiva y no elimina aperturas preexistentes. Si se ejecuta en otra fecha, actualizar la marca de causa en PRE y POST por una nueva marca trazable.

---

## GRUPO 1 - Funcional

### TC01 - Cuenta de deposito especial sin parametro DEPCUENTA habilitado

**ID consolidado:** `TCO-CON-013` (RN-14, RAMA-042/RAMA-043).

| Campo | Detalle |
|-------|---------|
| **@i_cta** | `'0000144029'` -- cuenta real verificada: estado `A`, moneda `1`, sin bloqueo vigente tipo `1`/`3`; empresa especial `2291`. |
| **@s_ssn** | `261006013` -- identificador sin colision en `cc_tran_monet`; reemplazar si ya fue consumido al ejecutar. |
| **@i_sp** | `'N'` -- deposito normal, discriminador necesario para entrar a la validacion de `DEPCUENTA`. |
| **Regla** | RN-14 / RAMA-043: cuenta incluida en `ad_emp_dep_especial` y parametro efectivo `DEPCUENTA='N'`. |
| **estado_evidencia** | `SUPUESTO_CONTROLADO`: la apertura de caja de sesion no existe en BD y requiere el PRE de la seccion anterior. Cuenta, ausencia de bloqueos, catalogo y parametro `DEPCUENTA` verificados; el resultado de ruta se confirmo con EXEC y rollback. |

#### Ficha de ruta

| Campo | Detalle |
|-------|---------|
| Objetivo declarado | Rechazar el deposito normal de una cuenta especial cuando `DEPCUENTA='N'`. |
| Parametros efectivos | `@s_org='U'`, `@i_canal='VEN'`, `@i_cta='0000144029'`, `@i_sp='N'`, `@i_mon=1`, `@t_corr='N'`, `@t_trn=3040`, `@i_aplcobis='S'`, `@s_ofi=100`, `@s_rol=1`, `@s_user='CAJERO01'`. |
| Validaciones previas | 1. El error remoto no aplica (`@s_org_err=NULL`). 2. La cuenta no esta en `cuentas_con_referencia`. 3. La caja de sesion debe existir. 4. La cuenta existe y no esta terminada (`cc_estado='A'`). 5. No tiene bloqueo vigente tipo `1`/`3`. 6. No entra a validacion SBS de deposito inicial (`cc_estado` distinto de `D`). 7. La validacion de cuentas rotativas debe retornar `0`; el EXEC avanzo hasta la rama objetivo. 8. Existe catalogo de cuenta especial activo con empresa `2291`. 9. `sp_con_parametroconf` debe entregar `DEPCUENTA='N'`. |
| Discriminadores y estado | `cc_cta_banco='0000144029'`: `VERIFICADA`, fila obtenida con `cc_ctacte=11515`, estado `A`, moneda `1`. Bloqueos (`cb_estado='V'` y tipo `1`/`3`): `VERIFICADA`, conteo `0`. `cuentas_con_referencia`: `VERIFICADA`, conteo `0`. Apertura `re_caja` con oficina `100`, rol `1`, usuario `CAJERO01`, producto `APE`, moneda `1`, transaccion `3015`, ubicacion `0`: `SUPUESTO_CONTROLADO`, conteo inicial `0`; INSERT exacto probado con rollback. Catalogo `ad_emp_dep_especial`: `VERIFICADA`, estado `A`, empresa `2291`. Configuracion: `VERIFICADA`, `pa_val_booleano='N'` y default `N`. Cuentas rotativas: `VERIFICADA` por ejecucion, porque la llamada retorna el rechazo posterior de DEPCUENTA. |
| Evidencia SQL | `verify` devolvio `cc_ctacte=11515`, `cc_estado='A'`, `cc_moneda=1`, `bloqueos_ruta=0`, `ct_est_catalogo='A'`, `empresa='2291'`, `pa_val_booleano='N'`, default `N`; cuenta con referencia `0`. `exec-rollback` final lanzo el mensaje esperado y confirmo rollback con `total_caja_sesion=0`, `marca_tc13=0`, cuenta `A` y `total_tran=0` antes y despues. |

#### Plantilla de ejecucion del SP

```sql
DECLARE @ret int
DECLARE @s_date datetime
DECLARE @o_nombre varchar(30), @o_impuesto money, @o_neto money,
        @o_ssn int, @o_consulta int, @o_novedad_sbs char(1),
        @o_msg_error varchar(132), @o_fecha_contable varchar(10),
        @o_servicio_not varchar(5), @o_cod_ente varchar(20),
        @o_celular varchar(10), @o_correo varchar(64),
        @o_valor varchar(11), @o_valor1 varchar(11),
        @o_prod_deb char(3), @o_cta_lat char(3)

SELECT @s_date = GETDATE()

EXEC @ret = cob_cuentas..sp_tr_deposito_rc
    @s_ssn = 261006013,
    @s_srv = 'SRV_CTE',
    @s_lsrv = 'SRV_CTE_LOC',
    @s_user = 'CAJERO01',
    @s_sesn = NULL,
    @s_term = 'CAJA01',
    @s_date = @s_date,
    @s_ofi = 100,
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
    @i_cta = '0000144029',
    @i_efe = 100.00,
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
    @o_nombre = @o_nombre OUTPUT,
    @o_impuesto = @o_impuesto OUTPUT,
    @o_neto = @o_neto OUTPUT,
    @o_ssn = @o_ssn OUTPUT,
    @o_consulta = @o_consulta OUTPUT,
    @i_ssn = NULL,
    @i_date_off = NULL,
    @i_canal = 'VEN',
    @i_aplcobis = 'S',
    @i_ruta_transito = NULL,
    @i_nomb_dep = NULL,
    @e_cds = NULL,
    @o_novedad_sbs = @o_novedad_sbs OUTPUT,
    @o_msg_error = @o_msg_error OUTPUT,
    @o_fecha_contable = @o_fecha_contable OUTPUT,
    @i_iden_dep = NULL,
    @i_debito = NULL,
    @i_val_consep = NULL,
    @i_denominaciones = '',
    @e_cod_trx = 0,
    @e_verde = 'N',
    @e_uuid = '',
    @o_servicio_not = @o_servicio_not OUTPUT,
    @o_cod_ente = @o_cod_ente OUTPUT,
    @o_celular = @o_celular OUTPUT,
    @o_correo = @o_correo OUTPUT,
    @o_valor = @o_valor OUTPUT,
    @o_valor1 = @o_valor1 OUTPUT,
    @o_prod_deb = @o_prod_deb OUTPUT,
    @o_cta_lat = @o_cta_lat OUTPUT

SELECT @ret AS retorno, @o_ssn AS o_ssn, @o_consulta AS o_consulta,
       @o_novedad_sbs AS o_novedad_sbs, @o_msg_error AS o_msg_error,
       @o_nombre AS o_nombre, @o_impuesto AS o_impuesto, @o_neto AS o_neto
GO
```

**PRE - Preparacion y verificaciones requeridas en BD:**
```sql
-- Ejecutar primero la PRECONDICION COMUN DE SESION documentada arriba.
SELECT c.cc_cta_banco, c.cc_ctacte, c.cc_estado, c.cc_moneda,
       (SELECT COUNT(1) FROM cob_cuentas..cc_ctabloqueada x
         WHERE x.cb_cuenta = c.cc_ctacte AND x.cb_estado = 'V'
           AND x.cb_tipo_bloqueo IN ('1','3')) AS bloqueos_ruta
FROM cob_cuentas..cc_ctacte c
WHERE c.cc_cta_banco = '0000144029'
-- Esperado: cc_ctacte=11515, estado='A', moneda=1, bloqueos_ruta=0.

SELECT b.ct_cod_catalogo, b.ct_est_catalogo, b.ct_otro_campo_catalogo AS empresa,
       p.pa_val_booleano
FROM db_biz_admempresa..ba_tabla a
INNER JOIN db_biz_admempresa..ba_catalogo b
    ON CONVERT(varchar(30), a.tb_cod_tabla) = CONVERT(varchar(30), b.ct_cod_tabla)
LEFT JOIN db_biz_admempresa..ba_parametroconf p
    ON CONVERT(varchar(30), p.pa_cod_empresa) = b.ct_otro_campo_catalogo
   AND p.pa_cod_producto = 4
   AND p.pa_cod_servicio = 'REE'
   AND p.pa_cod_parametro = 'DEPCUENTA'
WHERE a.tb_nom_tabla = 'ad_emp_dep_especial'
  AND CONVERT(varchar(30), b.ct_cod_catalogo) = '0000144029'
  AND b.ct_est_catalogo = 'A'
-- Esperado: empresa='2291', pa_val_booleano='N'.

SELECT COUNT(1) AS cuenta_con_referencia
FROM cobis..cl_catalogo a
INNER JOIN cobis..cl_tabla b ON a.tabla = b.codigo
WHERE b.tabla = 'cuentas_con_referencia'
  AND CONVERT(varchar(30), a.codigo) = '0000144029'
-- Esperado: 0.

SELECT COUNT(1) AS transacciones_pre
FROM cob_cuentas..cc_tran_monet
WHERE CONVERT(varchar(30), tm_cta_banco) = '0000144029'
-- Baseline observado: 0.
```

**POST - Validaciones y limpieza en BD:**
```sql
SELECT TOP 5 tm_hora, tm_cta_banco, tm_tipo_tran, tm_canal
FROM cob_cuentas..cc_tran_monet
WHERE CONVERT(varchar(30), tm_cta_banco) = '0000144029'
ORDER BY tm_hora DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; rechazo por DEPCUENTA='N').

SELECT COUNT(1) AS transacciones_post
FROM cob_cuentas..cc_tran_monet
WHERE CONVERT(varchar(30), tm_cta_banco) = '0000144029'
-- Debe ser igual a transacciones_pre; en la confirmacion fue 0.

SELECT cc_cta_banco, cc_estado
FROM cob_cuentas..cc_ctacte
WHERE cc_cta_banco = '0000144029'
-- Debe conservar estado 'A'.

-- Limpieza inversa exacta de PRECONDICION COMUN DE SESION.
DELETE FROM cob_remesas..re_caja
WHERE cj_oficina = 100 AND cj_rol = 1 AND cj_operador = 'CAJERO01'
  AND cj_producto = 'APE' AND cj_moneda = 1 AND cj_transaccion = 3015
  AND cj_ubicacion = 0
  AND cj_fecha_real = CONVERT(datetime, CONVERT(varchar(10), GETDATE(), 101))
  AND cj_causa = 'QA06102026TC13'
```

**Resultado esperado:** Excepcion de negocio desde `cobis..sp_cerror`, `@i_num=999999`: `ERROR: ESTA TRANSACCION DEBE HACERLA POR DEPOSITO ESPECIAL` (verificado 2026-10-06). El texto de `cob_cuentas..sp_tr_deposito_rc` contiene esta rama y despues `RETURN 1` (origen localizado en `sp_text`, linea 832); el driver recibio la excepcion de `sp_cerror`, no un valor `@ret` separado. `cobis..cl_errores` para `999999` muestra otro mensaje, por lo que no se uso como fuente causal.

**Trazabilidad por DB:**
- `cob_cuentas..cc_ctacte` -- SELECT de estado y cuenta; la rama devuelve antes de mutar la cuenta.
- `cob_cuentas..cc_ctabloqueada` -- SELECT de bloqueos vigentes; cero filas para tipos `1`/`3`.
- `db_biz_admempresa..ba_tabla`, `ba_catalogo`, `ba_parametroconf` -- SELECT del catalogo especial y configuracion `DEPCUENTA='N'`.
- `cob_remesas..re_caja` -- SELECT de apertura por `sp_verifica_caja_rc`; INSERT condicional de PRE y DELETE inverso marcado.
- `cob_cuentas..cc_tran_monet` -- sin INSERT; baseline y postvalidacion sin nuevas filas.
- Origen del rechazo: `cob_cuentas..sp_tr_deposito_rc` -> `cobis..sp_cerror`, codigo COBIS `999999`, `sp_text` linea 832.

---

## TABLAS MONITOREADAS

| Tabla | Base | Operacion | Campo cuenta | Top | Campos a ignorar | Filtro contenido |
|-------|------|-----------|--------------|-----|------------------|------------------|
| `cc_ctacte` | `cob_cuentas` | SELECT | `cc_cta_banco='0000144029'` | N/A | - | estado `A`; `cc_ctacte=11515` |
| `cc_ctabloqueada` | `cob_cuentas` | SELECT | `cb_cuenta=11515 AND cb_estado='V' AND cb_tipo_bloqueo IN ('1','3')` | N/A | - | conteo esperado `0` |
| `cc_tran_monet` | `cob_cuentas` | SELECT | `tm_cta_banco='0000144029'` | `TOP 5 tm_hora DESC` | - | sin nuevas filas |
| `ba_tabla` | `db_biz_admempresa` | SELECT | `tb_nom_tabla='ad_emp_dep_especial'` | N/A | - | define catalogo de cuentas especiales |
| `ba_catalogo` | `db_biz_admempresa` | SELECT | `ct_cod_catalogo='0000144029'` | N/A | - | estado `A`, empresa `2291` |
| `ba_parametroconf` | `db_biz_admempresa` | SELECT | `pa_cod_empresa=2291 AND pa_cod_producto=4 AND pa_cod_servicio='REE' AND pa_cod_parametro='DEPCUENTA'` | N/A | - | valor `N` |
| `re_caja` | `cob_remesas` | SELECT / INSERT PRE / DELETE POST | `cj_oficina=100 AND cj_rol=1 AND cj_operador='CAJERO01' AND cj_producto='APE' AND cj_moneda=1 AND cj_transaccion=3015 AND cj_ubicacion=0` | N/A | - | fecha actual; limpieza exige `cj_causa='QA06102026TC13'` |
| `re_cuadre` | `cob_remesas` | SELECT | `cd_oficina=100 AND cd_rol=1 AND cd_operador='CAJERO01' AND cd_moneda=1 AND cd_ubicacion=0` | N/A | - | validacion de caja cerrada |
| `cl_tabla` | `cobis` | SELECT | `tabla='cuentas_con_referencia'` | N/A | - | resuelve catalogo |
| `cl_catalogo` | `cobis` | SELECT | `codigo='0000144029'` o codigo de origen | N/A | - | cuenta no clasificada con referencia |

---

## TABLAS MONITOREADAS POR SPs HIJOS

`NO_APLICA` para mutaciones por SPs hijos en la ruta confirmada. `sp_verifica_caja_rc`, `sp_val_ctas_rotativas` y `sp_con_parametroconf` se ejecutan como validaciones de lectura; el rechazo se lanza por `cobis..sp_cerror`. La unica mutacion del escenario es la apertura controlada de caja en PRE, revertida por el DELETE marcado en POST.
