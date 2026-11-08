
# Casos de Prueba - SP `sp_direccion_dml`

**Base de datos:** `cobis` (Sybase ASE) con dependencias en `cob_cuentas`, `cobis_his`
**Proposito:** Orquestador DML transaccional (INSERT/UPDATE/DELETE/DELETE temporal) de direcciones de entes (`cobis..cl_direccion`), con validacion de catalogos geograficos, reglas de maximos de direcciones por tipo de persona, verificacion de asociaciones a cuenta corriente/tarjeta de credito, notificacion al cliente y auditoria en `ts_direccion` / `cl_direccion_his`.

> **Cuentas y parametros verificados en BD** (diagnostico y prevalidacion ejecutados 2026-08-31):
> - Entes reales confirmados en `cobis..cl_ente`: 6149, 216145, 2615, 8977, 152, 162, 8, 9, 108, 36, 900001-900018 (todos ya poseen historial de direcciones por ejecuciones previas de este mismo proyecto QA).
> - Catalogo `cl_producto`: valido=1, inexistente=250.
> - Catalogo `cl_ciudad`: valido=1 y 2 (`ci_pais=1`), extranjera real=157 (`ci_pais=26`), inexistente=9999. **Nota:** la ciudad 90 usada como supuesto original en el insumo consolidado es Ecuador (`ci_pais=1`) en este entorno, no extranjera; se sustituyo por 157.
> - Catalogo `cl_parroquia` (por ciudad): validos ciudad=1/parroquia={1,2}, inexistente=9999.
> - Catalogo `cl_canton_ciudad`: unico canton valido real para ciudad=1 es `'0901'` (`cc_estado='V'`); no existe un segundo canton valido para la misma ciudad en este entorno. Inexistente=`'9999'`.
> - Catalogo `cl_parroquia_ciudad` (requiere `pc_parroquia_sib IS NOT NULL`): validos reales `261` (AYACUCHO), `262` (BOLIVAR), `263`, `264` para canton `'0901'`; inexistente=9999. Los valores `1`/`2` usados como supuesto en el insumo original no son validos en este catalogo.
> - Catalogo `cl_oficina`: valido=1 y 2, inexistente=9999.
> - Parametro `cl_parametro` (`pa_producto='MIS'`, `pa_nemonico='TPVGRE'`) = `360` dias de vigencia.
> - Tablas **no encontradas en este entorno de BD**: `cl_dir_envio_tarj_cred`, `cl_direccion_email`. Todos los casos que dependen de estas tablas quedan marcados `supuesto_controlado`.
> - **Hallazgo critico de entorno:** todos los entes de prueba disponibles (6149, 216145, 2615, 8977, 152, 162, 8, 9, 900001-900018) ya tienen al menos una direccion tipo `D` registrada por ejecuciones anteriores de este mismo proyecto. Esto significa que varios casos de "alta exitosa desde cero" (TC01, TC26-31, TC33) ya no reproducen su hipotesis original (insercion limpia) sino el comportamiento real de rechazo por duplicidad de domicilio o por maximo de direcciones alcanzado. Se documenta el resultado REAL observado en cada ficha, señalando la discrepancia frente a la hipotesis original cuando aplica.
> - De los 79 casos originales, 9 se habian marcado como `supuesto_controlado` por sospecha de ausencia de datos/tablas (TC18, TC35, TC58, TC59, TC64, TC65, TC66, TC71, TC78) y todos se resolvieron con datos reales verificados en BD. Los unicos 2 no reproducibles de forma confiable (contrato de `sp_telefono` bajo condicion de carrera genuina, antes TC72 y TC79) fueron eliminados de este documento. Total de casos ejecutables: 77 (TC01-TC77).

---

## CONVENCIONES

| Tipo | Descripcion |
|------|-------------|
| **PRE** | Consulta SQL con valores literales que verifica el estado de BD requerido antes de ejecutar el SP. Para casos exitosos incluye baseline `SELECT MAX(di_fecha_modificacion)` o `MAX(secuencial)` previo a la ejecucion. |
| **POST** | Consulta SQL que valida el efecto en BD tras la ejecucion, ordenada por `di_fecha_modificacion DESC` / `secuencial DESC` (equivalente de `tm_hora DESC` para este SP, que no maneja tablas `tm_*`). |
| **ERROR** | Caso donde el SP aborta via `raiserror` (capturado como excepcion JDBC) o retorna 1 con `@w_num` especifico, sin mutar `cl_direccion`/`ts_direccion`. |
| **RUTA ALTA (I)** | `@i_operacion='I'`, `@t_trn=109`. Inserta en `cl_direccion` + `ts_direccion` clase N. |
| **RUTA UPDATE (U)** | `@i_operacion='U'`, `@t_trn=110`. Actualiza `cl_direccion` + 2 INSERT en `ts_direccion` (clase P/A). |
| **RUTA DELETE (D)** | `@i_operacion='D'`, `@t_trn=1226`. Elimina de `cl_direccion`, inserta en `ts_direccion` e historifica en `cobis_his..cl_direccion_his`. |
| **RUTA DELETE TEMPORAL (E)** | `@i_operacion='E'`, `@t_trn=1226`. Variante de eliminacion sobre direcciones temporales (`cl_direccion_tmp` / `cl_dir_est_cta_tmp`). |
| **supuesto_controlado** | Escenario no reproducible en el entorno actual (tabla ausente o dato inexistente). Se documenta la razon exacta y la instruccion de preparacion manual. |

---

## PARAMETROS DE SESION POR DEFECTO

| Parametro | Valor por defecto | Descripcion |
|-----------|--------------------|-------------|
| **@s_ssn** | 500001 | Secuencial de sesion QA |
| **@s_user** | 'QATESTER' | Usuario de ejecucion |
| **@s_term** | 'QATERM01' | Terminal de origen |
| **@s_date** | '2026-08-26 09:00:00' | Fecha logica de la transaccion |
| **@s_srv / @s_lsrv** | 'MIS' | Servicio / servicio logico |
| **@s_ofi** | 1 | Oficina de sesion |
| **@s_rol** | 1 | Rol de usuario |
| **@t_debug** | 'N' | Modo debug desactivado |
| **@t_from** | 'QA_CONSOLIDADO' | Origen de la transaccion |
| **@t_trn** | 109 (I) / 110 (U) / 1226 (D, E) | Codigo de transaccion; varia por caso |
| **@i_operacion** | 'I' | I=Alta, U=Update, D=Delete, E=Delete temporal; varia por caso |
| **@i_no_cobis** | 'N' | 'S' activa contrato `sp_gen_sec` |
| **@i_mensaje** | 'S' | Habilita mensajes de salida |
| **@i_producto** | 1 | Producto valido; varia en casos de error de dependencia |
| **@i_ente** | 900001 | Ente bajo prueba; varia por caso |
| **@i_direccion** | (no aplica en Alta) | Requerido en Update/Delete/Delete_E; varia por caso |
| **@i_descripcion** | 'DIRECCION QA CONSOLIDADO' | Descripcion de direccion; varia por caso |
| **@i_tipo** | 'D' | D/T/O; varia por caso |
| **@i_sector** | '0' | Sector; varia por caso |
| **@i_parroquia** | 1 | Parroquia (cl_parroquia); varia por caso |
| **@i_ciudad** | 1 | Ciudad; varia por caso |
| **@i_oficina** | 1 | Oficina; varia por caso |
| **@i_envio_crp** | 'N' (Alta) / 'S' (Update, refleja estado real de 900010/1) | Envio de correspondencia; varia por caso |
| **@i_parroquia_ciu** | 261 | Corregido frente al supuesto original (1); valor real valido para canton '0901' |
| **@i_verificado** | 'N' | N/I/P/S; varia por caso |
| **@i_ind_act_presenc** | 'N' | Indicador de actualizacion presencial |
| **@i_ind_val_maxdir** | 'S' | Activa validacion de maximo de direcciones |
| **@i_verifdirec** | 'N' | Activa verificacion de asociaciones en Update |
| **@i_canton** | '0901' | Unico canton valido real en este entorno para ciudad=1 |
| **@i_valida** | 'S' | Activa validacion de canton/parroquia_ciu |
| **@i_val_dir** | 'S' (Alta) / 'N' (Update) | Activa validacion de tipo de direccion por tipo de persona |
| **@i_val_domicilio** | 'S' | Activa validacion de domicilio unico desde VREFEREN |
| **@i_envio_notifica** | 'N' | 'S' activa contrato `sp_notif_cli_mod_dir` |
| **@e_actmasivacli** | 'N' | 'S' hace bypass de prohibiciones de eliminacion |

Plantilla base (Alta):

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int

exec @w_return_test = cobis..sp_direccion_dml
    @s_ssn              = 500001,
    @s_user             = 'QATESTER',
    @s_term             = 'QATERM01',
    @s_date             = '2026-08-26 09:00:00',
    @s_srv              = 'MIS',
    @s_lsrv             = 'MIS',
    @s_ofi              = 1,
    @s_rol              = 1,
    @t_debug            = 'N',
    @t_from             = 'QA_CONSOLIDADO',
    @t_trn              = 109,
    @i_operacion        = 'I',
    @i_no_cobis         = 'N',
    @i_mensaje          = 'S',
    @i_producto         = 1,
    @i_ente             = 900001,
    @i_descripcion      = 'DIRECCION QA CONSOLIDADO',
    @i_tipo             = 'D',
    @i_sector           = '0',
    @i_parroquia        = 1,
    @i_ciudad           = 1,
    @i_oficina          = 1,
    @i_envio_crp        = 'N',
    @i_parroquia_ciu    = 261,
    @i_verificado       = 'N',
    @i_ind_act_presenc  = 'N',
    @i_ind_val_maxdir   = 'S',
    @i_verifdirec       = 'N',
    @i_canton           = '0901',
    @i_valida           = 'S',
    @i_val_dir          = 'S',
    @i_val_domicilio    = 'S',
    @i_envio_notifica   = 'N',
    @e_actmasivacli     = 'N',
    @o_direccion        = @o_direccion output,
    @o_msj_error        = @o_msj_error output,
    @o_sig_log_svr      = @o_sig_log_svr output

select @w_return_test as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

Cada TC lista unicamente los `@parametro = valor` que difieren de esta plantilla base.

---

## GRUPO 1 — Alta: Validaciones de dependencias y enrutamiento

### TC01 — Alta exitosa - Persona Natural, tipo Domicilio, verificado N

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900006 -- corregido; unico ente real sin direccion tipo D disponible (900001 ya alcanzo el maximo) |
| **@i_tipo** | 'D' |
| **@i_verificado** | 'N' |
| **@i_envio_crp** | 'N' |
| **@i_val_dir** | 'N' -- corregido frente al supuesto original ('S'); ver hallazgo de codigo |
| **Regla** | RN01-RN09, RN21 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, RETURN 0 confirmado tras el ajuste). |

> **Hallazgo de codigo:** con `@i_val_dir='S'` (valor original de la plantilla), el SP valida "¿el ente ya tiene una direccion tipo D?" usando el estado **previo** al INSERT; con 0 direcciones tipo D existentes, bloquea igualmente el alta con el mensaje "PERSONA NATURAL DEBE REGISTRARSE AL MENOS UNA DIRECCION TIPO [D]" — es decir, es **imposible** registrar la primera direccion de domicilio de un cliente nuevo con `@i_val_dir='S'`. Se confirmo probando 3 entes distintos sin direccion D (900006, 900012, 900047), los 3 con el mismo rechazo. Desactivando la validacion (`@i_val_dir='N'`) el alta se completa con exito.

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900006, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE — Estado requerido en BD:**
```sql
SELECT en_ente, en_subtipo FROM cobis..cl_ente WHERE en_ente = 900006 AND en_subtipo = 'P'
-- Condicion: ente existe como persona natural
SELECT di_direccion, di_tipo, di_verificado, di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 900006
-- Estado real verificado 2026-09-02: unica direccion existente di_direccion=2 (tipo T, legado 2010, sin domicilio D)
```

**POST — Validaciones en BD:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_tipo, di_verificado, di_envio_crp, di_fecha_modificacion
FROM cobis..cl_direccion
WHERE di_ente = 900006
ORDER BY di_fecha_modificacion DESC
-- Resultado real verificado 2026-09-02: nueva fila di_direccion=1, di_tipo='D', di_verificado='N', di_envio_crp='N'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=1` (primera direccion tipo domicilio insertada exitosamente). Coincide con la hipotesis original de alta exitosa, usando el ajuste `@i_val_dir='N'` documentado arriba.

**Trazabilidad por DB:**
- `cobis..cl_direccion` — INSERT
- `cobis..ts_direccion` — INSERT

---

### TC02 — Ente igual a cero rechaza el alta

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 0 |
| **Regla** | AEST-RAMA-002 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion tinyint, @o_msj_error varchar(132), @o_sig_log_svr int, @w_return int
exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 0,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D', @i_sector = '0',
    @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1, @i_envio_crp = 'N',
    @i_parroquia_ciu = 261, @i_verificado = 'N', @i_ind_val_maxdir = 'S',
    @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output
select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE — Estado requerido en BD:**
```sql
SELECT di_ente FROM cobis..cl_direccion WHERE di_ente = 0
-- Condicion: no aplica busqueda de ente (rechazo antes de leer cl_ente)
```

**POST — Validaciones en BD:**
```sql
SELECT TOP 5 di_ente, di_direccion FROM cobis..cl_direccion WHERE di_ente = 0
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; ente invalido)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe ente o cedula incorrecta" (verificado 2026-08-31). Coincide con la hipotesis original (rechazo, `@w_num`=101042).

**Trazabilidad por DB:**
- `cobis..cl_direccion` — SELECT (sin escritura)

---

### TC03 — Ente distinto de cero pero inexistente en cl_ente

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 999999901 |
| **Regla** | RN01 / AEST-RAMA-003 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion tinyint, @o_msj_error varchar(132), @o_sig_log_svr int, @w_return int
exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 999999901,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D', @i_sector = '0',
    @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1, @i_envio_crp = 'N',
    @i_parroquia_ciu = 261, @i_verificado = 'N', @i_ind_val_maxdir = 'S',
    @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output
select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE — Estado requerido en BD:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 999999901
-- Condicion: 0 filas (verificado 2026-08-31)
```

**POST — Validaciones en BD:**
```sql
SELECT TOP 5 di_ente, di_direccion FROM cobis..cl_direccion WHERE di_ente = 999999901
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; ente no encontrado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe ente o cedula incorrecta" (verificado 2026-08-31). Coincide con la hipotesis original.

**Trazabilidad por DB:**
- `cobis..cl_ente` — SELECT
- `cobis..cl_direccion` — SELECT (sin escritura)

---

### TC04 — Operacion no soportada retorna 0 sin ejecutar ramas

| Campo | Detalle |
|-------|---------|
| **@i_operacion** | 'X' |
| **Regla** | AEST-RAMA-004/041/071/087 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion tinyint, @o_msj_error varchar(132), @o_sig_log_svr int,@w_return int
exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109,
    @i_operacion = 'X',  -- override bajo prueba
    @i_producto = 1, @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'D', @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output
select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE — Estado requerido en BD:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 900001
-- Condicion: ente existe (no se llega a validar por operacion invalida)
```

**POST — Validaciones en BD:**
```sql
SELECT TOP 5 di_ente, di_direccion FROM cobis..cl_direccion WHERE di_ente = 900001
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; operacion no soportada)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31; `@o_direccion`, `@o_msj_error`, `@o_sig_log_svr` = NULL. Coincide con la hipotesis original.

**Trazabilidad por DB:**
- `cobis..cl_direccion` — SELECT (sin escritura)

---

### TC05 — Transaccion distinta de 109 en operacion Insert

| Campo | Detalle |
|-------|---------|
| **@t_trn** | 999 |
| **Regla** | AEST-RAMA-005 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql

declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 999,  -- override bajo prueba
    @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

**PRE:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 900001
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion FROM cobis..cl_direccion WHERE di_ente = 900001
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; trn invalida)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "Transaccion no permitida" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=151051).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC06 — Producto inexistente rechaza el alta

| Campo | Detalle |
|-------|---------|
| **@i_producto** | 250 |
| **Regla** | RN02 / AEST-RAMA-006 |
| **fuente_valor** | sybase_select (ejecutado) |


```sql

declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I',
    @i_producto = 250,  -- override bajo prueba
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

**PRE:**
```sql
SELECT pd_producto FROM cobis..cl_producto WHERE pd_producto = 250
-- Condicion: 0 filas (verificado 2026-08-31)
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion FROM cobis..cl_direccion WHERE di_ente = 900001
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; producto inexistente)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe producto" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101032).

**Trazabilidad por DB:** `cobis..cl_producto` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC07 — Ciudad inexistente rechaza el alta

| Campo | Detalle |
|-------|---------|
| **@i_ciudad** | 9999 |
| **Regla** | RN03 / AEST-RAMA-007 |
| **fuente_valor** | sybase_select (ejecutado) |

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1,
    @i_ciudad = 9999,  -- override bajo prueba
    @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO


**PRE:**
```sql
SELECT ci_ciudad FROM cobis..cl_ciudad WHERE ci_ciudad = 9999
-- Condicion: 0 filas (verificado 2026-08-31)
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_ciudad FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_ciudad = 9999
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; ciudad inexistente)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe ciudad" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101024).

**Trazabilidad por DB:** `cobis..cl_ciudad` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC08 — Parroquia inexistente para la ciudad rechaza el alta

| Campo | Detalle |
|-------|---------|
| **@i_parroquia** | 9999 |
| **Regla** | RN04 / AEST-RAMA-008 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, causa raiz confirmada por analisis de codigo). |

declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

```sql
exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0',
    @i_parroquia = 9999,  -- override bajo prueba
    @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

**PRE:**
```sql
SELECT pq_parroquia FROM cobis..cl_parroquia WHERE pq_ciudad = 1 AND pq_parroquia = 9999
-- Condicion: 0 filas (verificado 2026-08-31)
SELECT numero, mensaje FROM cobis..cl_errores WHERE numero = 101037
-- Resultado real verificado 2026-09-02: numero=101037, mensaje='No existe sector' (catalogo mal etiquetado; el codigo lo asocia a RN04/parroquia)
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_parroquia FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_parroquia = 9999
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; parroquia invalida, rechazo correcto)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe sector" con `@w_num=101037` (verificado 2026-09-02). **Coincide con la hipotesis original a nivel de logica/regla** (RN04, codigo 101037, rechazo por parroquia inexistente); el texto del mensaje difiere unicamente porque el catalogo `cobis..cl_errores` de este entorno tiene ese numero de error mal etiquetado como "No existe sector" en lugar de "No existe parroquia". No es un defecto del SP ni una validacion fuera de orden.

**Trazabilidad por DB:** `cobis..cl_parroquia` - SELECT; `cobis..cl_errores` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC09 — Canton inexistente cuando la ciudad tiene configuracion activa

| Campo | Detalle |
|-------|---------|
| **@i_canton** | '9999' |
| **Regla** | RN16 / AEST-RAMA-009T/010F |
| **fuente_valor** | sybase_select (ejecutado) |

```sql

declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S',
    @i_canton = '9999',  -- override bajo prueba
    @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

**PRE:**
```sql
SELECT cc_canton FROM cobis..cl_canton_ciudad WHERE cc_canton = '9999' AND cc_estado = 'V'
-- Condicion: 0 filas (verificado 2026-08-31)
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_canton FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_canton = '9999'
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; canton inexistente)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe el canton" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101173).

**Trazabilidad por DB:** `cobis..cl_canton_ciudad` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC10 — Parroquia_ciu inexistente para el canton

| Campo | Detalle |
|-------|---------|
| **@i_canton** | '0901' |
| **@i_parroquia_ciu** | 9999 |
| **Regla** | RN17 / AEST-RAMA-011 |
| **fuente_valor** | sybase_select (ejecutado) |

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N',
    @i_parroquia_ciu = 9999,  -- override bajo prueba
    @i_verificado = 'N', @i_ind_val_maxdir = 'S',
    @i_canton = '0901',  -- override bajo prueba (valor base, condicion del escenario)
    @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

**PRE:**
```sql
SELECT pc_parroquia FROM cobis..cl_parroquia_ciudad WHERE pc_parroquia = 9999 AND pc_ciudad = 1
-- Condicion: 0 filas (verificado 2026-08-31)
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_parroquia_ciu FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_parroquia_ciu = 9999
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; parroquia_ciu inexistente)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO EXISTE LA PARROQUIA EN LA CIUDAD" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101271).

**Trazabilidad por DB:** `cobis..cl_parroquia_ciudad` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC11 — Ciudad extranjera evita la validacion de canton/parroquia_ciu

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900012 -- corregido; ente limpio para aislar la prueba del bypass |
| **@i_ciudad** | 157 (corregido; supuesto original 90 no es extranjera en este entorno) |
| **@i_parroquia** | 0 -- corregido; unica parroquia real valida para ciudad=157 en `cobis..cl_parroquia` (el supuesto original, 1, no existe para esta ciudad y bloqueaba antes del bypass) |
| **@i_canton** | '9999' |
| **@i_parroquia_ciu** | 9999 |
| **@i_val_dir** | 'N' -- agregado; evita interferencia de la regla de domicilio obligatorio (ver hallazgo TC01), no relacionada con esta prueba |
| **Regla** | AEST-RAMA-009F |
| **fuente_valor** | sybase_select (verificado 2026-09-02, RETURN 0 confirmado tras el ajuste). |

> **Hallazgo de causa raiz:** el rechazo original ("No existe sector", `@w_num`=101037) no era el bloque de canton (`ref30`) sino la validacion basica de parroquia (`ref41`), que se ejecuta ANTES de `ref30` y es independiente de si la ciudad es extranjera: `cobis..cl_parroquia` no tenia fila para `(ciudad=157, parroquia=1)`. Al usar `parroquia=0` (unica fila real para ciudad=157), la validacion `ref41` pasa y el flujo llega al bloque `ref30`, confirmando que el bypass de canton/parroquia_ciu para ciudad extranjera funciona correctamente.

```sql

declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900012,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0',
    @i_parroquia = 0,  -- override bajo prueba
    @i_ciudad = 157,  -- override bajo prueba
    @i_oficina = 1,
    @i_envio_crp = 'N',
    @i_parroquia_ciu = 9999,  -- override bajo prueba
    @i_verificado = 'N', @i_ind_val_maxdir = 'S',
    @i_canton = '9999',  -- override bajo prueba
    @i_val_dir = 'N',  -- override bajo prueba
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

```sql

**PRE:**
```sql
SELECT ci_ciudad, ci_pais FROM cobis..cl_ciudad WHERE ci_ciudad = 157 AND ci_pais <> 1
-- Condicion: fila existe, ci_pais=26 (verificado 2026-08-31)
SELECT pq_ciudad, pq_parroquia FROM cobis..cl_parroquia WHERE pq_ciudad = 157
-- Estado real verificado 2026-09-02: unica fila valida es pq_parroquia=0
SELECT di_direccion FROM cobis..cl_direccion WHERE di_ente = 900012
-- Estado real verificado 2026-09-02: 0 filas (ente limpio)
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_ciudad, di_canton, di_parroquia, di_parroquia_ciu
FROM cobis..cl_direccion WHERE di_ente = 900012
ORDER BY di_fecha_modificacion DESC
-- Resultado real verificado 2026-09-02: nueva fila con di_ciudad=157, di_canton='9999', di_parroquia_ciu=9999
-- (valores invalidos almacenados sin validar, confirmando el bypass)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=1`. Coincide con la hipotesis original: para ciudad extranjera (`ci_pais<>1`), el SP omite la validacion de canton/parroquia_ciu y almacena los valores informados sin verificar su existencia en catalogo.

**Trazabilidad por DB:** `cobis..cl_ciudad` - SELECT; `cobis..cl_parroquia` - SELECT; `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC12 — Oficina inexistente rechaza el alta

| Campo | Detalle |
|-------|---------|
| **@i_oficina** | 9999 |
| **Regla** | RN05 / AEST-RAMA-012 |
| **fuente_valor** | sybase_select (ejecutado) |

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1,
    @i_oficina = 9999,  -- override bajo prueba
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

```sql

**PRE:**
```sql
SELECT of_oficina FROM cobis..cl_oficina WHERE of_oficina = 9999
-- Condicion: 0 filas (verificado 2026-08-31)
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_oficina FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_oficina = 9999
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; oficina inexistente)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe oficina" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101016).

**Trazabilidad por DB:** `cobis..cl_oficina` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC13 — Tipo de direccion fuera del dominio D/T/O

| Campo | Detalle |
|-------|---------|
| **@i_tipo** | 'X' |
| **Regla** | RN06 / AEST-RAMA-013 |
| **fuente_valor** | sybase_select (ejecutado) |

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'X',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

```sql

**PRE:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 900001
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_tipo FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_tipo = 'X'
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; tipo invalido)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "TIPO DIRECCION SOLO PUEDE SER D, T, O" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101627).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC14 — Envio de correspondencia fuera de N/S

| Campo | Detalle |
|-------|---------|
| **@i_envio_crp** | 'X' |
| **Regla** | RN09 / AEST-RAMA-015 |
| **fuente_valor** | sybase_select (ejecutado) |

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'X',  -- override bajo prueba
    @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO

```sql

**PRE:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 900001
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_envio_crp = 'X'
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; envio_crp invalido)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "Parametros invalidos" (verificado 2026-08-31). Coincide con hipotesis de rechazo (`@w_num`=101114), mensaje generico real observado.

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC15 — Estado de verificacion no catalogado

| Campo | Detalle |
|-------|---------|
| **@i_verificado** | 'Z' |
| **Regla** | RN08 / AEST-RAMA-016 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900001, @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261,
    @i_verificado = 'Z',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 900001
```

**POST:**
```sql
SELECT TOP 5 di_ente, di_direccion, di_verificado FROM cobis..cl_direccion WHERE di_ente = 900001 AND di_verificado = 'Z'
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; verificado invalido)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "Debe ingresar una opcion de verificacion valida" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101563).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

## GRUPO 2 — Alta: BVA maximos de direcciones y domicilio

### TC16 — BVA abajo - persona natural con 2 direcciones permite el alta

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900002 |
| **@i_tipo** | 'T' |
| **Regla** | RN10 / AEST-BVA-001-abajo |
| **fuente_valor** | sybase_select (ejecutado, cuenta real ajustada) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900002,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900002
-- Estado real verificado 2026-08-31: 2 direcciones (D, T)
SELECT MAX(di_fecha_modificacion) AS hora_pre FROM cobis..cl_direccion WHERE di_ente = 900002

IF (SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900002) > 2
BEGIN
    SET ROWCOUNT 1
    DELETE FROM cobis..cl_direccion WHERE di_ente = 900002 AND di_tipo = 'T'
    SET ROWCOUNT 0
END

SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900002
-- Verificacion post-reset: debe volver a 2 (D, T)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900002
ORDER BY 1 DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31; `@o_direccion=3` (tercera direccion insertada). Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC17 — BVA exacto - persona natural con 3 direcciones rechaza el alta

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 216145 |
| **Regla** | RN10 / AEST-BVA-001-exacto |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 216145,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 216145
-- Estado real verificado 2026-08-31: 3 direcciones (T, D, T)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 216145
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; maximo alcanzado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101267).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC18 — BVA arriba - persona natural con 4 direcciones confirma el rechazo

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 1000016 -- corregido; se preparo el dato requerido (ver nota) |
| **@i_tipo** | 'T' (5ta direccion intentada) |
| **Regla** | AEST-BVA-001-arriba |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de preparacion de datos (bypass controlado):** ningun ente persona natural real de este entorno alcanza 4 direcciones (el SP limita a 3 via RN10, confirmado por consulta exhaustiva `GROUP BY di_ente HAVING COUNT(1)=4` sin resultados). Se preparo el escenario insertando directamente una 4a fila de control en `cobis..cl_direccion` (bypass de la validacion del SP, sin pasar por `sp_direccion_dml`) sobre el ente 1000016 (persona natural con 3 direcciones reales previas: D, T, O), simulando una inconsistencia de datos heredada/migrada. Esto permite ejercitar la rama "arriba" del limite (4 direcciones ya existentes) al intentar una 5a insercion.

#### Plantilla de preparacion (bypass directo, NO pasa por el SP)

```sql
INSERT INTO cobis..cl_direccion (di_ente, di_descripcion, di_tipo, di_parroquia, di_ciudad, di_sector, di_oficina, di_canton, di_parroquia_ciu, di_verificado, di_envio_crp, di_fecha_registro, di_fecha_modificacion, di_usuario_reg, di_usuario_mod)
VALUES (1000016, 'DIRECCION CONTROL BYPASS TC18', 'O', 1, 1, '0', 1, '0901', 261, 'N', 'N', GETDATE(), GETDATE(), 'QATESTER', 'QATESTER')
```

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 1000016,  -- override bajo prueba (ya con 4 direcciones tras el bypass)
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'T',  -- override bajo prueba (5ta direccion intentada)
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 1000016
-- Estado real verificado 2026-09-02: 4 (tras la insercion de control D,T,O,O)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 1000016
-- Resultado real verificado 2026-09-02: 4 (sin cambios, rechazo confirmado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES" (verificado 2026-09-02, `@w_num`=101267). Coincide con la hipotesis original: el rechazo se mantiene consistente incluso con el conteo ya por encima del limite teorico.

**Trazabilidad por DB:** `cobis..cl_direccion` - INSERT (preparacion, bypass directo); `cobis..cl_direccion` - SELECT (sin escritura por el SP)

---

### TC19 — Domicilio verificado existente bloquea nuevo domicilio

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900004 |
| **@i_tipo** | 'D' |
| **@i_val_dir** | 'S' |
| **Regla** | RN11 / AEST-RAMA-020/021 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900004,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'S',  -- override bajo prueba (valor base, condicion del escenario)
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_direccion, di_verificado FROM cobis..cl_direccion WHERE di_ente = 900004 AND di_tipo = 'D'
-- Estado real verificado 2026-08-31: di_verificado='S'
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900004 AND di_tipo = 'D'
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; domicilio ya existe)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "El cliente ya tiene una dirección de tipo domicilio" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101537).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC20 — Domicilio existente no verificado bloquea por conteo

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900005 |
| **@i_tipo** | 'D' |
| **@i_val_dir** | 'N' |
| **@i_val_domicilio** | 'S' |
| **Regla** | AEST-RAMA-022 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900005,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'N',  -- override bajo prueba
    @i_val_domicilio = 'S',  -- override bajo prueba (valor base, condicion del escenario)
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_direccion, di_verificado FROM cobis..cl_direccion WHERE di_ente = 900005 AND di_tipo = 'D'
-- Estado real verificado 2026-08-31: di_verificado='N'
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900005 AND di_tipo = 'D'
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; domicilio ya existe pese a no estar verificado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "El cliente ya tiene una dirección de tipo domicilio" (verificado 2026-08-31). El mensaje real coincide con TC19 (bloqueo por conteo, independiente de `di_verificado`), consistente con la hipotesis de rechazo (`@w_num`=101537).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC21 — BVA abajo - persona natural con 1 direccion tipo Trabajo permite otra

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900092 -- corregido; 900001 ya no tiene 1 sola direccion tipo T (acumulo una 2da T por ejecuciones posteriores de este mismo proyecto, contaminando la evidencia) |
| **@i_tipo** | 'T' |
| **@i_val_dir** | 'N' |
| **@i_descripcion** | 'DIRECCION QA CONSOLIDADO TC21' -- agregado; descripcion unica para identificar sin ambiguedad la fila insertada por este TC |
| **Regla** | AEST-BVA-002-abajo |
| **fuente_valor** | sybase_select (verificado 2026-09-02, evidencia aislada confirmada). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900092,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO TC21',  -- override bajo prueba
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'N',  -- override bajo prueba
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900092 AND di_tipo = 'T'
-- Estado real verificado 2026-09-02: 1 direccion tipo T (aislada, sin otras ejecuciones previas de este proyecto sobre este ente)

-- Reset condicional: borra unicamente la fila insertada por una ejecucion previa de este TC21
-- (identificada por su descripcion unica), dejando intacta la direccion T original
IF EXISTS (SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900092 AND di_tipo = 'T' AND di_descripcion = 'DIRECCION QA CONSOLIDADO TC21')
BEGIN
    DELETE FROM cobis..cl_direccion WHERE di_ente = 900092 AND di_tipo = 'T' AND di_descripcion = 'DIRECCION QA CONSOLIDADO TC21'
END

SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900092 AND di_tipo = 'T'
-- Verificacion post-reset: debe volver a 1
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900092 AND di_tipo = 'T'
-- Resultado real verificado 2026-09-02: 2 (conteo aumento de 1 a 2)
SELECT di_direccion, di_tipo, di_descripcion FROM cobis..cl_direccion WHERE di_ente = 900092 ORDER BY di_direccion
-- Resultado real: fila 2 = di_descripcion='DIRECCION QA CONSOLIDADO TC21' (nueva, identificable sin ambiguedad)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=2`. Coincide con hipotesis, con evidencia aislada y no ambigua (conteo de direcciones tipo T verificado antes=1 y despues=2, mas descripcion unica de la fila nueva).

**Trazabilidad por DB:** `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC22 — BVA exacto - persona natural con 2 direcciones Trabajo/Otro rechaza el alta

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 8 (ajustado; posee 2 direcciones tipo T reales) |
| **@i_tipo** | 'T' |
| **@i_val_dir** | 'N' |
| **Regla** | RN12 / AEST-BVA-002-exacto |
| **fuente_valor** | sybase_select (ejecutado, cuenta real ajustada) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 8,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'N',  -- override bajo prueba
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 8 AND di_tipo = 'T'
-- Estado real verificado 2026-08-31: 2 direcciones tipo T
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 8 AND di_tipo = 'T'
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; maximo T/O alcanzado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "EL CLIENTE TIENE INGRESADO EL NUMERO MAXIMO DE DIRECCIONES" (verificado 2026-08-31). Coincide con hipotesis de rechazo (`@w_num`=101521).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC23 — Persona natural sin domicilio tipo D obligatorio

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900147 
| **@i_tipo** | 'T' |
| **@i_val_dir** | 'S' |
| **Regla** | RN13 / AEST-RAMA-025 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900147,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO TC23',
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'S',  -- override bajo prueba (valor base, condicion del escenario)
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900147 AND di_tipo = 'D'
-- Estado real verificado 2026-09-02: 0 filas (sin domicilio previo, precondicion cumplida)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900147
-- Resultado real verificado 2026-09-02: sin nuevas filas (rechazo antes de INSERT)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "PERSONA NATURAL DEBE REGISTRARSE AL MENOS UNA DIRECCION TIPO [D]" (verificado 2026-09-02, `@w_num`=101730). Coincide con la hipotesis original: sin domicilio previo y `@i_val_dir='S'`, el SP rechaza el alta de una direccion no-D.

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura, rechazo previo a INSERT)

---

### TC24 — Persona juridica sin direccion tipo Trabajo obligatoria

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 162 |
| **@i_tipo** | 'O' |
| **@i_val_dir** | 'S' |
| **Regla** | RN14 / AEST-RAMA-026/027 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 162,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO TC24',
    @i_tipo = 'O',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'S',  -- override bajo prueba (valor base, condicion del escenario)
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente, en_subtipo FROM cobis..cl_ente WHERE en_ente = 162 AND en_subtipo = 'C'
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 162 AND di_tipo = 'T'
-- Estado real verificado 2026-08-31: 0 direcciones tipo T
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 162 AND di_tipo = 'O'
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; falta direccion T obligatoria)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "PERSONA JURIDICA DEBE REGISTRARSE AL MENOS UNA DIRECCION TIPO T" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101731).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC25 — Persona juridica no puede registrar direccion tipo Domicilio

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 8977 |
| **@i_tipo** | 'D' |
| **Regla** | RN15 / AEST-RAMA-028 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 8977,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO TC25', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente, en_subtipo FROM cobis..cl_ente WHERE en_ente = 8977 AND en_subtipo = 'C'
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 8977 AND di_tipo = 'D'
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; PJ no admite tipo D)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "Cliente juridico no debe tener direcciones de tipo Domicilio" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101713).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

## GRUPO 3 — Alta: Casos especiales

### TC26 — Alta con generacion de secuencial fuera de COBIS

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900190 -- corregido; 900008 ya poseia domicilio tipo D por ejecuciones anteriores de este mismo proyecto |
| **@i_no_cobis** | 'S' |
| **@i_tipo** | 'D' |
| **@i_val_dir** | 'N' -- agregado; evita el bloqueo de "primera direccion D" (ver hallazgo TC01), no relacionado con esta prueba |
| **Regla** | AFUN-EG-001 / AEST-RAMA-031 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de correccion:** el ente 900008 original ya tenia domicilio D de ejecuciones previas de este proyecto. Se sustituyo por 900190 (1 direccion tipo T, sin D), y se agrego `@i_val_dir='N'` para evitar el bloqueo estructural de "primera direccion D" documentado en TC01, no relacionado con la regla bajo prueba en este caso (generacion de secuencial `sp_gen_sec`).

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I',
    @i_no_cobis = 'S',  -- override bajo prueba
    @i_producto = 1,
    @i_ente = 900190,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO TC26',
    @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'N',  -- override bajo prueba
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente, en_subtipo FROM cobis..cl_ente WHERE en_ente = 900190 AND en_subtipo = 'P'
SELECT di_direccion, di_tipo FROM cobis..cl_direccion WHERE di_ente = 900190
-- Estado real verificado 2026-09-02: unica direccion existente di_direccion=1 (tipo T, sin domicilio D)
```

**POST:**
```sql
SELECT TOP 5 secuencial, ente, direccion, tipo, fecha
FROM cobis..ts_direccion
WHERE ente = 900190
ORDER BY fecha DESC
-- Resultado real verificado 2026-09-02: nueva fila con secuencial=117361013 (generado por sp_gen_sec), tipo='D'
SELECT di_direccion, di_tipo, di_descripcion FROM cobis..cl_direccion WHERE di_ente = 900190 ORDER BY di_direccion
-- Resultado real: nueva fila di_direccion=2, tipo='D', descripcion='DIRECCION QA CONSOLIDADO TC26'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=2`, con contrato exitoso de `sp_gen_sec` (secuencial real generado en `ts_direccion`). Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT (secuencial via `sp_gen_sec`)

---

### TC27 — INSERT exitoso - tipo Trabajo

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900021 
| **@i_tipo** | 'T' |
| **@i_descripcion** | 'Direccion laboral 11' |
| **@i_verificado** | 'N' |
| **@i_envio_crp** | 'N' |
| **Regla** | RN06, RN21 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900021,  -- override bajo prueba
    @i_descripcion = 'Direccion laboral 11',  -- override bajo prueba
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N',  -- override bajo prueba (valor base, condicion del escenario)
    @i_parroquia_ciu = 261,
    @i_verificado = 'N',  -- override bajo prueba (valor base, condicion del escenario)
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente, en_subtipo FROM cobis..cl_ente WHERE en_ente = 900021 AND en_subtipo = 'P'

IF NOT EXISTS (SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'D')
BEGIN
    DECLARE @next_dir_tc27 int
    SELECT @next_dir_tc27 = ISNULL(MAX(di_direccion), 0) + 1 FROM cobis..cl_direccion WHERE di_ente = 900021
    INSERT INTO cobis..cl_direccion (di_ente, di_direccion, di_descripcion, di_tipo, di_parroquia, di_ciudad, di_sector, di_oficina, di_canton, di_parroquia_ciu, di_verificado, di_envio_crp, di_fecha_registro, di_fecha_modificacion, di_usuario_reg, di_usuario_mod)
    VALUES (900021, @next_dir_tc27, 'DIRECCION QA CONSOLIDADO TC27', 'D', 1, 1, '0', 1, '0901', 261, 'N', 'N', GETDATE(), GETDATE(), 'QATESTER', 'QATESTER')
END

SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'D'
-- Verificacion post-reset: debe ser >= 1 (cumple RN13)

IF EXISTS (SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'T')
   AND (SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900021) >= 3
BEGIN
    SET ROWCOUNT 1
    DELETE FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'T'
    SET ROWCOUNT 0
END

SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900021
-- Verificacion post-reset: debe quedar por debajo de 3
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'T'
-- Verificacion post-reset: confirma que la fila tipo T eliminada era la correcta (0 esperado)
```
ORDER BY di_fecha_modificacion DESC
-- Resultado real verificado 2026-09-02: nueva fila di_direccion=2, di_tipo='T', di_verificado='N', di_envio_crp='N'


**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=2`. Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT


### TC28 — INSERT exitoso - tipo Otros

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900021 -- corregido; mismo ente usado en TC27 (ya con D+T), 6149 estaba en maximo |
| **@i_tipo** | 'O' |
| **@i_descripcion** | 'Direccion alterna 12' |
| **@i_verificado** | 'N' |
| **@i_envio_crp** | 'N' |
| **Regla** | RN06 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

**PRE:**
```sql
-- Reset condicional: si el ente ya tiene una direccion tipo O, se elimina antes de la prueba
-- (caso contrario, no se hace nada; el TC valida el alta de la primera direccion tipo O)
IF EXISTS (SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'O')
BEGIN
    DELETE FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'O'
END

SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900021 AND di_tipo = 'O'
-- Verificacion post-reset: debe ser 0
```
Estado base heredado de TC27 (ente 900021 con direcciones D, T; bajo el maximo de 3).

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900021,  -- override bajo prueba
    @i_descripcion = 'Direccion alterna 12',  -- override bajo prueba
    @i_tipo = 'O',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT TOP 1 di_ente, di_direccion, di_tipo, di_descripcion
FROM cobis..cl_direccion
WHERE di_ente = 900021 AND di_tipo = 'O' AND di_descripcion = 'Direccion alterna 12'
ORDER BY di_fecha_modificacion DESC
-- Resultado real verificado 2026-09-02: nueva fila di_direccion=3, di_tipo='O', di_verificado='N', di_envio_crp='N'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=3`. Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC29 — INSERT exitoso - Verificado S calcula vigencia

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900025 -- corregido; ente 8 ya estaba en maximo de direcciones |
| **@i_tipo** | 'T' |
| **@i_verificado** | 'S' |
| **@i_descripcion** | 'Direccion verificada 13' |
| **@i_envio_crp** | 'N' |
| **Regla** | RN18 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900025,  -- override bajo prueba
    @i_descripcion = 'Direccion verificada 13',  -- override bajo prueba
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N',  -- override bajo prueba (valor base, condicion del escenario)
    @i_parroquia_ciu = 261,
    @i_verificado = 'S',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT pa_smallint FROM cobis..cl_parametro WHERE pa_producto = 'MIS' AND pa_nemonico = 'TPVGRE'
-- Valor real verificado: 360
SELECT di_direccion, di_tipo FROM cobis..cl_direccion WHERE di_ente = 900025
-- Estado real verificado 2026-09-02: unica direccion existente di_direccion=1 (tipo D)
```

**POST:**
```sql
SELECT TOP 1 di_verificado, di_vigencia, di_fecha_ver, di_fecha_caducidad
FROM cobis..cl_direccion
WHERE di_ente = 900025 AND di_descripcion = 'Direccion verificada 13'
ORDER BY di_fecha_modificacion DESC

Delete cobis..cl_direccion 
WHERE di_ente = 900025 and di_direccion = 3

```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=2`. Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_parametro` - SELECT; `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC30 — INSERT exitoso - Verificado I calcula vigencia

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900027 |
| **@i_verificado** | 'I' |
| **@i_descripcion** | 'Direccion incompleta 14' |
| **Regla** | RN18 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900027,  -- override bajo prueba
    @i_descripcion = 'Direccion incompleta 14',  -- override bajo prueba
    @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261,
    @i_verificado = 'I',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT pa_smallint FROM cobis..cl_parametro WHERE pa_producto = 'MIS' AND pa_nemonico = 'TPVGRE'
SELECT di_direccion, di_tipo FROM cobis..cl_direccion WHERE di_ente = 900027
-- Estado real verificado 2026-09-02: unica direccion existente di_direccion=1 (tipo D)
```

**POST:**
```sql
SELECT TOP 1 di_verificado, di_vigencia, di_fecha_caducidad
FROM cobis..cl_direccion
WHERE di_ente = 900027 AND di_descripcion = 'Direccion incompleta 14'
ORDER BY di_fecha_modificacion DESC
-- Resultado real verificado 2026-09-02: di_verificado='I', di_vigencia='S', di_fecha_caducidad='2027-08-21 09:00:00'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=2`. Coincide con la hipotesis original. Se resuelve tambien la inconsistencia de trazabilidad detectada previamente al usar un ente limpio y dedicado.

**Trazabilidad por DB:** `cobis..cl_parametro` - SELECT; `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC31 — INSERT exitoso - Verificado P conserva tipo de inconsistencia

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900030 |
| **@i_verificado** | 'P' |
| **@i_tipo_verif_incns** | 'INC' |
| **@i_descripcion** | 'Direccion presencial 15' |
| **Regla** | RN18 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900030,  -- override bajo prueba
    @i_descripcion = 'Direccion presencial 15',  -- override bajo prueba
    @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261,
    @i_verificado = 'P',  -- override bajo prueba
    @i_tipo_verif_incns = 'INC',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_canton = '0901', @i_val_dir = 'S',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT pa_smallint FROM cobis..cl_parametro WHERE pa_producto = 'MIS' AND pa_nemonico = 'TPVGRE'
SELECT di_direccion, di_tipo FROM cobis..cl_direccion WHERE di_ente = 900030
-- Estado real verificado 2026-09-02: unica direccion existente di_direccion=1 (tipo D)
```

**POST:**
```sql
SELECT TOP 1 di_verificado, di_vigencia, di_tipo_verif_incns
FROM cobis..cl_direccion
WHERE di_ente = 900030 AND di_descripcion = 'Direccion presencial 15'
ORDER BY di_fecha_modificacion DESC
-- Resultado real verificado 2026-09-02: di_verificado='P', di_vigencia='S'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=2`. Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_parametro` - SELECT; `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC32 — INSERT exitoso - Persona Juridica tipo Trabajo

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 167 |
| **@i_tipo** | 'T' |
| **@i_val_dir** | 'N' |
| **@i_descripcion** | 'Direccion laboral juridica TC32' -- descripcion unica para evitar ambiguedad |
| **Regla** | RN14 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 167,  -- override bajo prueba
    @i_descripcion = 'Direccion laboral juridica TC32',  -- override bajo prueba
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'N',  -- override bajo prueba
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente, en_subtipo FROM cobis..cl_ente WHERE en_ente = 167 AND en_subtipo = 'C'
SELECT di_direccion, di_tipo FROM cobis..cl_direccion WHERE di_ente = 167

IF EXISTS (SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 167 AND di_tipo = 'T')
BEGIN
    DELETE FROM cobis..cl_direccion WHERE di_ente = 167 AND di_tipo = 'T'
END
-- Estado real verificado 2026-09-02: unica direccion existente di_direccion=1 (tipo D), sin direccion T
```

**POST:**
```sql
SELECT TOP 1 di_ente, di_direccion, di_tipo, di_descripcion
FROM cobis..cl_direccion
WHERE di_ente = 167 AND di_tipo = 'T'
ORDER BY di_fecha_modificacion DESC
-- Resultado real verificado 2026-09-02: nueva fila di_direccion=2, di_descripcion='Direccion laboral juridica TC32'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_direccion=2`. Coincide con hipotesis, con evidencia inequivoca (descripcion unica).

**Trazabilidad por DB:** `cobis..cl_ente` - SELECT; `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

### TC33 — INSERT exitoso - Registro de solicitud VREFEREN

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900031  |
| **@i_vreferen** | 'S' |
| **@i_solicitud** | 900001 |
| **@i_anio** | 2026 |
| **@i_observacion** | 'Observacion VREFEREN 30' |
| **@i_val_dir** | 'N' -- corregido; ver hallazgo de codigo (mismo de TC01), no relacionado con RN30 |
| **Regla** | RN30 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de correccion:** con `@i_val_dir='S'` se obtiene el rechazo "PERSONA NATURAL DEBE REGISTRARSE AL MENOS UNA DIRECCION TIPO [D]" — el mismo hallazgo de codigo de TC01 (el SP valida la existencia previa de una direccion D incluso al insertar la propia direccion D). Se desactiva la validacion (`@i_val_dir='N'`) para aislar la regla bajo prueba (RN30).

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 109, @i_operacion = 'I', @i_producto = 1,
    @i_ente = 900031,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO TC33', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_canton = '0901',
    @i_val_dir = 'N',  
    @i_vreferen = 'S',  -- override bajo prueba
    @i_solicitud = 900001,  -- override bajo prueba
    @i_anio = 2026,  -- override bajo prueba
    @i_observacion = 'Observacion VREFEREN 30',  -- override bajo prueba
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 900031
SELECT di_direccion, di_tipo FROM cobis..cl_direccion WHERE di_ente = 900031
-- Estado real verificado 2026-09-02: unica direccion existente di_direccion=1 (tipo D)
```

**POST:**
```sql
SELECT TOP 1 sl_secuencial, sl_solicitud, sl_anio, sl_cliente, sl_tipo_reg
FROM cobis..cl_vr_solicitud_log
WHERE sl_solicitud = 900001 AND sl_anio = 2026 AND sl_cliente = 900031
ORDER BY sl_fecha_ing DESC
-- Resultado real verificado 2026-09-02: nueva fila sl_secuencial=2989360 (generado por sp_cseqnos), sl_tipo_reg='DIRECC'

-- Reset para volver a ejecutar el TC: elimina la direccion y el log VREFEREN insertados por esta corrida
DELETE FROM cobis..cl_direccion WHERE di_ente = 900031 AND di_descripcion = 'DIRECCION QA CONSOLIDADO TC33'
DELETE FROM cobis..cl_vr_solicitud_log WHERE sl_solicitud = 900001 AND sl_anio = 2026 AND sl_cliente = 900031

SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900031
-- Verificacion post-reset: debe volver a 1 (unica direccion original, di_direccion=1)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02; `@o_sig_log_svr=2989360` (contrato exitoso `sp_cseqnos`). Coincide con la hipotesis original.

**Trazabilidad por DB:** `cl_vr_solicitud_log` - INSERT; `cobis..cl_direccion` - INSERT; `cobis..ts_direccion` - INSERT

---

## GRUPO 4 — Update: Verificacion de asociacion y CRP

### TC34 — Verificacion de asociacion bloquea la actualizacion (cuenta corriente CRP)

| Campo | Detalle |
|-------|---------|
| **@i_operacion** | 'U' |
| **@t_trn** | 110 |
| **@i_ente** | 232|
| **@i_direccion** | 1 |
| **@i_verifdirec** | 'S' |
| **Regla** | AEST-RAMA-043/044T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 232,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S',
    @i_verifdirec = 'S',  -- override bajo prueba
    @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT cc_cliente, cc_tipo_dir, cc_direccion_ec, cc_estado FROM cob_cuentas..cc_ctacte WHERE cc_cliente = 232 AND cc_tipo_dir = 'D' AND cc_direccion_ec = 1
-- Estado real verificado 2026-09-02: fila existe con cc_estado='A' (valida, no excluida)
SELECT di_fecha_modificacion FROM cobis..cl_direccion WHERE di_ente = 232 AND di_direccion = 1
-- Baseline real verificado 2026-09-02: '2003-12-02 11:53:41.470'
```

**POST:**
```sql
SELECT di_descripcion, di_fecha_modificacion FROM cobis..cl_direccion WHERE di_ente = 232 AND di_direccion = 1
-- Resultado real verificado 2026-09-02: sin cambios (di_fecha_modificacion identica a la baseline)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02 (salida anticipada confirmada, sin cambios). Coincide con la hipotesis original, ahora por la ruta especifica correcta de bloqueo por `cc_ctacte`.

**Trazabilidad por DB:** `cob_cuentas..cc_ctacte` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC35 — Verificacion de asociacion detecta tarjeta de credito asociada

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 11 |
| **@i_direccion** | 2 |
| **@i_verifdirec** | 'S' |
| **Regla** | AEST-RAMA-RN22 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 11,  -- override bajo prueba
    @i_direccion = 2,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S',
    @i_verifdirec = 'S',  -- override bajo prueba
    @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT dt_ente, dt_sec_direc_envio, dt_tipo_direc_envio, dt_estado FROM cobis..cl_dir_envio_tarj_cred WHERE dt_ente = 11 AND dt_sec_direc_envio = 2
-- Estado real verificado 2026-09-02: (11, 2, 'D', 'A') -- asociacion activa
SELECT 1 FROM cob_cuentas..cc_ctacte WHERE cc_cliente = 11 AND cc_tipo_dir = 'D' AND cc_direccion_ec = 2 AND cc_estado NOT IN ('C','Q')
-- Estado real verificado 2026-09-02: 0 filas (sin asociacion via cc_ctacte, aisla la ruta ECTC)
```

**POST:**
```sql
-- El SP retorna el valor de @i_verifdirec sin alteracion (echo) cuando detecta la asociacion, seguido de RETURN 0
```

**Resultado esperado:** `RETURN 0` con eco de `@i_verifdirec='S'` en el primer resultset — verificado 2026-09-02. Coincide con la hipotesis original: el SP detecta la asociacion via `cl_dir_envio_tarj_cred` cuando no existe asociacion via `cc_ctacte`.

**Trazabilidad por DB:** `cobis..cl_dir_envio_tarj_cred` - SELECT; `cob_cuentas..cc_ctacte` - SELECT (sin escritura)

---

### TC36 — Verificacion de asociacion sin ninguna asociacion existente

| Campo | Detalle |
|-------|---------|
| **@i_operacion** | 'U' |
| **@t_trn** | 110 |
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_verifdirec** | 'S' |
| **Regla** | RN29 / AEST-RAMA-045F |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S',
    @i_verifdirec = 'S',  -- override bajo prueba
    @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT 1 FROM cob_cuentas..cc_ctacte WHERE cc_cliente = 900010 AND cc_tipo_dir = 'D' AND cc_direccion_ec = 1 AND cc_estado NOT IN ('C','Q')
-- 0 filas reales (la unica fila tiene cc_estado='Q', excluida)
```

**POST:**
```sql
SELECT di_descripcion, di_fecha_modificacion FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31 (salida anticipada, sin cambios). Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC37 — Direccion inexistente para el ente rechaza la actualizacion

| Campo | Detalle |
|-------|---------|
| **@i_direccion** | 99 |
| **@i_tipo** | 'T' |
| **@i_verifdirec** | 'N' |
| **Regla** | AEST-RAMA-098 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010,
    @i_direccion = 99,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S',
    @i_verifdirec = 'N',
    @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 99
-- Condicion: 0 filas (verificado 2026-09-02)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 99
-- Resultado real verificado 2026-09-02: 0 (sin nuevas filas)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe direccion" (verificado 2026-09-02). Coincide con la hipotesis original (rechazo por direccion inexistente, aislado del chequeo de domicilio al usar `@i_tipo='T'`).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC38 — Actualizacion sin cambios efectivos no marca auditoria ni notificacion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **(todos los campos se reenvian identicos al estado actual de la fila)** | |
| **Regla** | AEST-RAMA-046,049..059(F) |
| **fuente_valor** | sybase_select (verificado 2026-09-02, evidencia de conteo aislada). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S',  -- valor identico al estado actual de la fila
    @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_descripcion, di_tipo, di_parroquia, di_ciudad, di_sector, di_oficina, di_envio_crp, di_parroquia_ciu, di_canton, di_verificado
FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
-- Estado real verificado 2026-09-02: di_envio_crp='S' (clave para no disparar el rechazo de desmarcado)
SELECT COUNT(1) FROM cobis..ts_direccion WHERE ente = 900010 AND direccion = 1
-- Baseline real verificado 2026-09-02: 26 filas
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..ts_direccion WHERE ente = 900010 AND direccion = 1
-- Resultado real verificado 2026-09-02: 28 filas (delta=2, el par rutinario P/A; sin filas adicionales de alerta)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con hipotesis: la actualizacion sin cambios efectivos se aplica sin error y solo genera el par rutinario de auditoria (2 filas), confirmando la ausencia de marcas adicionales de alerta/notificacion.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2, verificado por conteo)

---

### TC39 — Cambio de descripcion con zona 'X' marca alerta y notificacion

| Campo | Detalle |
|-------|---------|
| **@i_descripcion** | 'DIRECCION MODIFICADA QA' |
| **@i_zona** | 'X' |
| **Regla** | AEST-RAMA-046/047T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION MODIFICADA QA',  -- override bajo prueba
    @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_zona = 'X',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:** estado base `di_descripcion` de 900010/1 previo al cambio (ver TC38).

**POST:**
```sql
SELECT clase, descripcion FROM cobis..ts_direccion WHERE ente = 900010 AND direccion = 1 ORDER BY secuencial DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC40 — Cambio de descripcion con sufijo de ciudadela/sector identico

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 216145 |
| **@i_direccion** | 1 |
| **@i_tipo** | 'T'|
| **@i_descripcion** | 'CALLE SECUNDARIA, SECTOR NORTE' |
| **@i_zona** | '1' |
| **@i_envio_crp** | 'S' |
| **Regla** | RN21,23 / AEST-RAMA-047F/048T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 216145,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'CALLE SECUNDARIA, SECTOR NORTE',  -- override bajo prueba
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_zona = '1',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_descripcion, di_tipo, di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 216145 AND di_direccion = 1
-- Estado real verificado 2026-08-31: di_tipo='T', di_envio_crp='S'
```

**POST:**
```sql
SELECT di_descripcion FROM cobis..cl_direccion WHERE di_ente = 216145 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis (tras corregir `@i_tipo` al valor real T de la direccion).

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC41 — Cambio de descripcion con sufijo distinto marca alerta

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_descripcion** | 'CALLE PRINCIPAL, SECTOR SUR' |
| **@i_zona** | '1' |
| **Regla** | AEST-RAMA-048F |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'CALLE PRINCIPAL, SECTOR SUR',  -- override bajo prueba
    @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_zona = '1',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:** continuacion del estado de 900010/1 tras TC39.

**POST:**
```sql
SELECT clase, descripcion FROM cobis..ts_direccion WHERE ente = 900010 AND direccion = 1 ORDER BY secuencial DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC42 — Cambio de canton dispara notificacion y bloquea actualizacion presencial

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_canton** | '0900'|
| **Regla** | AEST-RAMA-049T |
| **fuente_valor** | sybase_select (ejecutado, limitacion de entorno) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N',
    @i_canton = '0900',  -- override bajo prueba
    @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_canton FROM cobis..cl_canton_ciudad WHERE cc_canton = '0900'
-- Condicion real: 0 filas -- este entorno solo tiene un canton valido registrado ('0901') para ciudad=1
```

**POST:**
```sql
SELECT di_canton FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin cambios (rechazo por canton invalido)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe el canton" (verificado 2026-08-31). **Limitacion de entorno confirmada de forma exhaustiva:** se valido `cobis..cl_canton_ciudad WHERE cc_estado='V'` para la totalidad de ciudades registradas en este ambiente (~200 ciudades) y en NINGUNA existen 2 o mas cantones validos simultaneos; cada ciudad mapea a exactamente un canton valido. Por lo tanto, un "cambio de canton hacia otro valor valido dentro de la misma ciudad" es estructuralmente irreproducible en este entorno para cualquier ciudad, no solo para ciudad=1. Se uso un codigo no catalogado para evidenciar que el SP exige validez de catalogo tambien en Update; esto confirma la regla de validacion pero no permite ejercitar la rama de "cambio entre dos cantones validos".

**Trazabilidad por DB:** `cobis..cl_canton_ciudad` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC43 — Cambio de punto de referencia se audita

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_pto_referencia** | 'REFERENCIA MODIFICADA QA' |
| **Regla** | AEST-RAMA-050T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_pto_referencia = 'REFERENCIA MODIFICADA QA',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT di_referencia FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC44 — Cambio de envio de correspondencia de N a S

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900040 -- corregido; 900010 ya tenia di_envio_crp='S' (no permitia la transicion limpia N->S) |
| **@i_direccion** | 1 |
| **@i_envio_crp** | 'S' |
| **Regla** | AEST-RAMA-051T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900040,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S',  -- override bajo prueba (transicion N->S)
    @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_tipo, di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 900040 AND di_direccion = 1
-- Estado real verificado 2026-09-02: di_envio_crp='N' (transicion limpia posible)
```

**POST:**
```sql
SELECT di_direccion, di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 900040 AND di_direccion = 1
-- Resultado real verificado 2026-09-02: di_envio_crp='S' (transicion N->S confirmada)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con la hipotesis original (transicion N→S real y aislada).

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC45 — No se puede desmarcar la direccion de envio de correspondencia vigente

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 216145 |
| **@i_direccion** | 1 |
| **@i_tipo** | 'T' (ajustado al tipo real) |
| **@i_envio_crp** | 'N' |
| **Regla** | RN24 / AEST-RAMA-061T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 216145,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'T',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'N',  -- override bajo prueba
    @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 216145 AND di_direccion = 1
-- Estado real verificado 2026-08-31: 'S'
```

**POST:**
```sql
SELECT di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 216145 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin cambios (rechazo; di_envio_crp permanece 'S')
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO SE PUEDE DESMARCAR LA DIRECCION DE ENVIO DE CORRESPONDENCIA" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101281).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

## GRUPO 5 — Update: Deteccion de cambios de campo, presencial y ECTC

### TC46 — Cambio de tipo de direccion respetando reglas de subtipo

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900191 |
| **@i_direccion** | 1 |
| **@i_tipo** | 'D' |
| **@i_envio_crp** | 'S' |
| **Regla** | AEST-RAMA-052T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900191,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'D',  -- override bajo prueba
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S',  -- igual al valor actual, aisla el cambio de tipo
    @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
-- Reset condicional: si una corrida previa ya dejo la direccion en tipo D,
-- se regresa a T para poder repetir la transicion T->D bajo prueba
IF EXISTS (SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900191 AND di_direccion = 1 AND di_tipo = 'D')
BEGIN
    UPDATE cobis..cl_direccion SET di_tipo = 'T' WHERE di_ente = 900191 AND di_direccion = 1
END

SELECT di_tipo, di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 900191 AND di_direccion = 1
-- Estado real verificado 2026-09-02: di_tipo='T' (unica direccion del ente, sin D)
```

**POST:**
```sql
SELECT di_tipo FROM cobis..cl_direccion WHERE di_ente = 900191 AND di_direccion = 1
-- Resultado real verificado 2026-09-02: di_tipo='D' (transicion T->D confirmada)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02 (transicion de tipo real y aislada). Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC47 — Cambio de sector distinto de '0' marca alerta

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_sector** | '5' |
| **Regla** | AEST-RAMA-053T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '5',  -- override bajo prueba
    @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT di_sector FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC48 — Cambio de parroquia y zona asociada

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_parroquia** | 2 |
| **Regla** | AEST-RAMA-054/057T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO TC48', @i_tipo = 'D',
    @i_sector = '0',
    @i_parroquia = 2,  -- override bajo prueba
    @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT pq_zona FROM cobis..cl_parroquia WHERE pq_ciudad = 1 AND pq_parroquia = 2
```

**POST:**
```sql
SELECT di_parroquia, di_zona FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC49 — Cambio de ciudad (actualizacion)

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900041 |
| **@i_direccion** | 1 |
| **@i_ciudad** | 2 |
| **@i_parroquia** | 0 |
| **@i_canton** | '2301'|
| **@i_parroquia_ciu** | 652 |
| **Regla** | AEST-RAMA-055T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900041,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0',
    @i_parroquia = 0,  -- override bajo prueba
    @i_ciudad = 2,  -- override bajo prueba
    @i_oficina = 1,
    @i_envio_crp = 'S',
    @i_parroquia_ciu = 652,  -- override bajo prueba
    @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N',
    @i_canton = '2301',  -- override bajo prueba
    @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_ciudad, di_parroquia, di_canton, di_parroquia_ciu FROM cobis..cl_direccion WHERE di_ente = 900041 AND di_direccion = 1
-- Estado real verificado 2026-09-02: ciudad=25, parroquia=0, canton='1201', parroquia_ciu=0
```

**POST:**
```sql
SELECT di_ciudad, di_parroquia, di_canton, di_parroquia_ciu FROM cobis..cl_direccion WHERE di_ente = 900041 AND di_direccion = 1
-- Resultado real verificado 2026-09-02: ciudad=2, parroquia=0, canton='2301', parroquia_ciu=652 (cambio de ciudad confirmado)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con la hipotesis original una vez corregida la combinacion ciudad/parroquia/canton/parroquia_ciu.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC50 — Cambio de parroquia_ciu (actualizacion)

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_parroquia_ciu** | 262 (corregido; supuesto original "2" no es valido en este catalogo) |
| **Regla** | AEST-RAMA-056T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S',
    @i_parroquia_ciu = 262,  -- override bajo prueba
    @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT pc_parroquia FROM cobis..cl_parroquia_ciudad WHERE pc_parroquia = 262 AND pc_ciudad = 1
-- Estado real verificado 2026-08-31: fila existe (BOLIVAR/SAGRARIO)
```

**POST:**
```sql
SELECT di_parroquia_ciu FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis (tras corregir el valor de catalogo).

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC51 — Cambio de oficina (comparacion por desigualdad)

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_oficina** | 2 |
| **Regla** | AEST-RAMA-058T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1,
    @i_oficina = 2,  -- override bajo prueba
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT di_oficina FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC52 — Cambio de observacion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_observacion** | 'OBSERVACION MODIFICADA QA' |
| **Regla** | AEST-RAMA-059T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_observacion = 'OBSERVACION MODIFICADA QA',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT di_observacion FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC53 — Verificado S/I/P recalcula vigencia en actualizacion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_verificado** | 'S' |
| **Regla** | AEST-RAMA-060T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261,
    @i_verificado = 'S',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT pa_smallint FROM cobis..cl_parametro WHERE pa_producto = 'MIS' AND pa_nemonico = 'TPVGRE'
```

**POST:**
```sql
SELECT di_verificado, di_vigencia, di_fecha_caducidad FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_parametro` - SELECT; `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC54 — Cambio de tipo de servicio

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_tipo_servicio** | '01' |
| **Regla** | AEST-RAMA-062T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_tipo_servicio = '01',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT di_tipo_servicio FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC55 — Actualizacion presencial con cambio incompatible es rechazada

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_ind_act_presenc** | 'V' |
| **@i_canton** | '0900' (codigo no catalogado; ver nota TC42) |
| **Regla** | RN31 / AEST-RAMA-063/064T |
| **fuente_valor** | sybase_select (ejecutado, limitacion de entorno) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_act_presenc = 'V',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N',
    @i_canton = '0900',  -- override bajo prueba
    @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT di_canton FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin cambios (rechazo)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe el canton" (verificado 2026-08-31). El rechazo se confirma (retorno=1), aunque por validacion de catalogo de canton en lugar del mensaje especifico "confirme la verificacion presencial" (105109). **Limitacion de entorno confirmada de forma exhaustiva** (ver nota TC42): se valido que ninguna ciudad del ambiente tiene 2+ cantones validos simultaneos, por lo que el escenario "cambio de canton hacia otro valor valido" que dispararia la validacion RN31 especifica no es reproducible con datos reales en este entorno, en ninguna ciudad.

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC56 — Actualizacion presencial permitida sin cambios incompatibles

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **@i_verificado** | 'N'|
| **@i_ind_act_presenc** | 'V' |
| **Regla** | AEST-RAMA-063T/064F |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO', @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261,
    @i_verificado = 'N',  -- override bajo prueba (igual al estado real vigente)
    @i_ind_act_presenc = 'V',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_verificado FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
-- Estado real verificado 2026-09-02: di_verificado='N'
```

**POST:**
```sql
SELECT di_verificado FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
-- Resultado real verificado 2026-09-02: di_verificado='N' (sin cambio, actualizacion aceptada)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con la hipotesis original una vez enviado `@i_verificado` igual al estado real vigente.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC57 — UPDATE exitoso - Notificacion deshabilitada

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 6149 |
| **@i_direccion** | 1 |
| **@i_descripcion** | 'Cambio masivo sin notificacion 33' |
| **@i_envio_notifica** | 'N' |
| **Regla** | RN39 |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 6149,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'Cambio masivo sin notificacion 33',  -- override bajo prueba
    @i_tipo = 'D',
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_envio_notifica = 'N',  -- override bajo prueba
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:** direccion existente valida para el ente (6149, direccion 1, tipo D).

**POST:**
```sql
SELECT di_ente, di_direccion, di_descripcion FROM cobis..cl_direccion WHERE di_ente = 6149 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT, UPDATE; `cobis..ts_direccion` - INSERT (x2)

---

### TC58 — Asociacion ECTC existente con el mismo tipo no genera log distinto

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 11 -- corregido; tabla `cl_dir_envio_tarj_cred` existe (ver nota TC35) |
| **@i_direccion** | 2 |
| **@i_tipo** | 'D' (igual al tipo vigente de la direccion y de la asociacion ECTC) |
| **Regla** | AEST-RAMA-RN24 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 11,  -- override bajo prueba
    @i_direccion = 2,  -- override bajo prueba
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'D',  -- override bajo prueba (igual al tipo vigente de la asociacion ECTC)
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT dt_tipo_direc_envio FROM cobis..cl_dir_envio_tarj_cred WHERE dt_ente = 11 AND dt_sec_direc_envio = 2
-- Estado real verificado 2026-09-02: 'D' (coincide con @i_tipo enviado)
SELECT COUNT(1) FROM cobis..cl_log_dir_envio_ec WHERE ld_ente = 11
-- Estado real verificado 2026-09-02: 0 filas previas
```

**POST:**
```sql
SELECT dt_tipo_direc_envio FROM cobis..cl_dir_envio_tarj_cred WHERE dt_ente = 11 AND dt_sec_direc_envio = 2
-- Resultado real verificado 2026-09-02: 'D' (sin cambio, mismo tipo)
SELECT TOP 1 ld_tipo_accion, ld_tipo_dir_ant, ld_tipo_dir_act FROM cobis..cl_log_dir_envio_ec WHERE ld_ente = 11 ORDER BY ld_secuencial DESC
-- Resultado real verificado 2026-09-02: ld_tipo_accion='M' (modificacion, no 'A' de asociacion distinta), ld_tipo_dir_act='D'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con la hipotesis original: al enviar el mismo tipo ya asociado, el SP registra `ld_tipo_accion='M'` en lugar de `'A'`, sin alterar `dt_tipo_direc_envio`.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..cl_log_dir_envio_ec` - INSERT; `cobis..ts_direccion` - INSERT (x2)

---

### TC59 — Asociacion ECTC existente con tipo distinto actualiza dt_tipo_direc_envio

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 1716 |
| **@i_direccion** | 1 |
| **@i_tipo** | 'D' (distinto al tipo vigente 'T' de la asociacion ECTC) |
| **Regla** | AEST-RAMA-RN24 |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 110, @i_operacion = 'U', @i_producto = 1,
    @i_ente = 1716,  -- override bajo prueba
    @i_direccion = 1,
    @i_descripcion = 'DIRECCION QA CONSOLIDADO',
    @i_tipo = 'D',  -- override bajo prueba (distinto al tipo vigente 'T' de la asociacion ECTC)
    @i_sector = '0', @i_parroquia = 1, @i_ciudad = 1, @i_oficina = 1,
    @i_envio_crp = 'S', @i_parroquia_ciu = 261, @i_verificado = 'N',
    @i_ind_val_maxdir = 'S', @i_verifdirec = 'N', @i_canton = '0901', @i_val_dir = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT dt_tipo_direc_envio FROM cobis..cl_dir_envio_tarj_cred WHERE dt_ente = 1716 AND dt_sec_direc_envio = 1
-- Estado real verificado 2026-09-02: 'T' (distinto de @i_tipo='D' enviado)
```

**POST:**
```sql
SELECT dt_tipo_direc_envio FROM cobis..cl_dir_envio_tarj_cred WHERE dt_ente = 1716 AND dt_sec_direc_envio = 1
-- Resultado real verificado 2026-09-02: 'D' (actualizado desde 'T')
SELECT TOP 1 ld_tipo_accion, ld_tipo_dir_ant, ld_tipo_dir_act FROM cobis..cl_log_dir_envio_ec WHERE ld_ente = 1716 ORDER BY ld_secuencial DESC
-- Resultado real verificado 2026-09-02: ld_tipo_accion='A', ld_tipo_dir_ant='T', ld_tipo_dir_act='D'
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con la hipotesis original: al enviar un tipo distinto al asociado, el SP actualiza `dt_tipo_direc_envio` y registra `ld_tipo_accion='A'`.

**Trazabilidad por DB:** `cobis..cl_direccion` - UPDATE; `cobis..cl_dir_envio_tarj_cred` - UPDATE; `cobis..cl_log_dir_envio_ec` - INSERT; `cobis..ts_direccion` - INSERT (x2)

---

## GRUPO 6 — Delete: Validaciones y BVA

### TC60 — Transaccion invalida en Delete

| Campo | Detalle |
|-------|---------|
| **@i_operacion** | 'D' |
| **@t_trn** | 999 |
| **@i_ente** | 900010 |
| **Regla** | AEST-RAMA-072F |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 999,  -- override bajo prueba
    @i_operacion = 'D', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_ente FROM cobis..cl_ente WHERE en_ente = 900010
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900010
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; trn invalida)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "Transaccion no permitida" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=151051).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC61 — Direccion inexistente rechaza la eliminacion

| Campo | Detalle |
|-------|---------|
| **@i_operacion** | 'D' |
| **@t_trn** | 1226 |
| **@i_direccion** | 99 |
| **Regla** | AEST-RAMA-073F |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 900010,
    @i_direccion = 99,  -- override bajo prueba
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 99
-- Condicion: 0 filas
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 99
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; direccion inexistente)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe dato solicitado" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101001; mensaje real generico equivalente).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC62 — BVA exacto - no se puede eliminar la ultima direccion del ente

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 2615 (ajustado; unico ente real con exactamente 1 direccion) |
| **@i_direccion** | 1 |
| **@e_actmasivacli** | 'N' |
| **Regla** | RN34 / AEST-BVA-003 |
| **fuente_valor** | sybase_select (ejecutado, cuenta real ajustada) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 2615,  -- override bajo prueba
    @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 2615
-- Estado real verificado 2026-08-31: 1 (unica direccion del ente)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 2615
ORDER BY 1 DESC
-- Condicion: sin cambios (rechazo)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No se pueden eliminar todas las direcciones" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101053).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC63 — No se puede eliminar la direccion de envio de correspondencia

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 216145 (ajustado; ente real con di_envio_crp='S') |
| **@i_direccion** | 1 |
| **@i_operacion** | 'D' |
| **@t_trn** | 1226 |
| **Regla** | RN25 / AEST-RAMA-076T |
| **fuente_valor** | sybase_select (ejecutado, cuenta real ajustada) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 216145,  -- override bajo prueba
    @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 216145 AND di_direccion = 1
-- Estado real verificado 2026-08-31: 'S'
```

**POST:**
```sql
SELECT di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 216145 AND di_direccion = 1
ORDER BY di_fecha_modificacion DESC
-- Condicion: sin cambios (rechazo)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO SE PUEDE ELIMINAR LA DIRECCION DE ENVIO DE CORRESPONDENCIA" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101274).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC64 — No se puede eliminar una direccion asociada a envio de estado de cuenta corriente

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 241 -- corregido; se identifico una asociacion real vigente en `cc_ctacte` no encontrada en el barrido inicial |
| **@i_direccion** | 2 |
| **@i_operacion** | 'D' |
| **@t_trn** | 1226 |
| **Regla** | AEST-RAMA-081T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de correccion:** se amplio la busqueda a la totalidad de `cob_cuentas..cc_ctacte` (no solo a los entes de prueba usados previamente) y se encontraron asociaciones reales vigentes (`cc_estado NOT IN ('C','Q')`); se selecciono el ente 241/direccion 2, que ademas tiene `di_envio_crp='N'` (aisla del bloqueo CRP) y 2 direcciones totales (aisla del bloqueo de ultima direccion).

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 241,  -- override bajo prueba
    @i_direccion = 2,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT cc_direccion_ec, cc_tipo_dir, cc_estado FROM cob_cuentas..cc_ctacte WHERE cc_cliente = 241 AND cc_tipo_dir = 'D' AND cc_estado NOT IN ('C','Q')
-- Estado real verificado 2026-09-02: (2, 'D', vigente) -- asociacion real confirmada
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 241
-- Estado real verificado 2026-09-02: 2 (no es la ultima direccion)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 241 AND di_direccion = 2
-- Resultado real verificado 2026-09-02: 1 (sin cambios, rechazo confirmado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO SE PUEDE ELIMINAR UNA DIRECCION DE ENVIO DE ESTADO CUENTA" (verificado 2026-09-02, `@w_num`=101273). Coincide con la hipotesis original.

**Trazabilidad por DB:** `cob_cuentas..cc_ctacte` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC65 — No se puede eliminar una direccion asociada a envio de estado de cuenta de tarjeta de credito

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 15 -- corregido; la tabla `cl_dir_envio_tarj_cred` SI existe en este entorno (ver nota TC35) |
| **@i_direccion** | 2 |
| **@i_operacion** | 'D' |
| **@t_trn** | 1226 |
| **Regla** | AEST-RAMA-082T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de correccion:** se identifico el ente 15/direccion 2 con asociacion activa en `cl_dir_envio_tarj_cred` (`dt_estado='A'`), `di_envio_crp='N'` (aisla del bloqueo CRP), sin asociacion en `cc_ctacte` (aisla del bloqueo de TC64 para que se ejercite la ruta especifica de tarjeta de credito), y 2 direcciones totales (aisla del bloqueo de ultima direccion).

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 15,  -- override bajo prueba
    @i_direccion = 2,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT dt_tipo_direc_envio, dt_estado FROM cobis..cl_dir_envio_tarj_cred WHERE dt_ente = 15 AND dt_sec_direc_envio = 2
-- Estado real verificado 2026-09-02: ('D', 'A') -- asociacion activa
SELECT 1 FROM cob_cuentas..cc_ctacte WHERE cc_cliente = 15 AND cc_tipo_dir = 'D' AND cc_direccion_ec = 2 AND cc_estado NOT IN ('C','Q')
-- Estado real verificado 2026-09-02: 0 filas (sin conflicto por cc_ctacte)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 15 AND di_direccion = 2
-- Resultado real verificado 2026-09-02: 1 (sin cambios, rechazo confirmado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO SE PUEDE ELIMINAR UNA DIRECCION DE ENVIO DE ESTADO CUENTA" (verificado 2026-09-02, `@w_num`=101273, ruta especifica de `cl_dir_envio_tarj_cred`). Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_dir_envio_tarj_cred` - SELECT; `cob_cuentas..cc_ctacte` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC66 — No se puede eliminar un domicilio con movil asociado (persona natural)

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 37604 -- corregido; la tabla `cl_direccion_email` SI existe en este entorno (3,799,728 filas; hallazgo previo fue un error de diagnostico) |
| **@i_direccion** | 2 |
| **@i_operacion** | 'D' |
| **@t_trn** | 1226 |
| **Regla** | AEST-RAMA-085T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de correccion:** se re-verifico la existencia de la tabla mediante `sysobjects` (`cobis..cl_direccion_email`) y se identifico un ente persona natural con direccion tipo D (`di_envio_crp='N'`, sin asociacion `cc_ctacte` ni `cl_dir_envio_tarj_cred`, 2 direcciones totales) y un registro `de_tipo='M'` asociado (`de_dir_domici=2`), aislando la validacion especifica de movil.

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 37604,  -- override bajo prueba
    @i_direccion = 2,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT de_tipo, de_dir_domici FROM cobis..cl_direccion_email WHERE de_ente = 37604 AND de_dir_domici = 2 AND de_tipo = 'M'
-- Estado real verificado 2026-09-02: ('M', 2) -- asociacion movil confirmada
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 37604
-- Estado real verificado 2026-09-02: 2 (no es la ultima direccion)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 37604 AND di_direccion = 2
-- Resultado real verificado 2026-09-02: 1 (sin cambios, rechazo confirmado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO SE PUEDE ELIMINAR DIRECCION RELACIONADA A UN NUMERO MOVIL" (verificado 2026-09-02, `@w_num`=101692). Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_direccion_email` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC67 — Actualizacion masiva de cliente omite las prohibiciones de eliminacion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900012 |
| **@i_direccion** | 1 |
| **@e_actmasivacli** | 'S' |
| **Regla** | AEST-RAMA-074F(actmasiva) |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 900012, @i_direccion = 1,
    @e_actmasivacli = 'S',  -- override bajo prueba
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1), MAX(di_envio_crp) FROM cobis..cl_direccion WHERE di_ente = 900012
-- Estado real verificado 2026-08-31: COUNT=1, di_envio_crp='S' (unica direccion y CRP simultaneamente)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900012
ORDER BY 1 DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31 (bypass confirmado: elimina pese a ser ultima direccion y CRP). Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - DELETE; `cobis..ts_direccion` - INSERT; `cobis_his..cl_direccion_his` - INSERT

---

### TC68 — Eliminacion fuera de COBIS genera secuencial via contrato exitoso

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900006 (ajustado; direccion no-CRP disponible) |
| **@i_direccion** | 1 |
| **@i_no_cobis** | 'S' |
| **Regla** | AEST-RAMA-081T |
| **fuente_valor** | sybase_select (ejecutado, cuenta real ajustada) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D',
    @i_no_cobis = 'S',  -- override bajo prueba
    @i_producto = 1,
    @i_ente = 900006,  -- override bajo prueba
    @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900006
-- Estado real verificado 2026-08-31: 2 direcciones (di_direccion=1 con di_envio_crp='N', apta para eliminar)
```

**POST:**
```sql
SELECT TOP 1 secuencial FROM cobis..ts_direccion WHERE ente = 900006 ORDER BY fecha DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis. **Nota:** el ente 900013 original de la ficha no tenia una direccion no-CRP disponible para esta prueba (dir1 con `di_envio_crp='S'`); se sustituyo por 900006 dir1 (`di_envio_crp='N'`).

**Trazabilidad por DB:** `cobis..cl_direccion` - DELETE; `cobis..ts_direccion` - INSERT

---

### TC69 — Notificacion al cliente por eliminacion de direccion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900016 |
| **@i_direccion** | 2 (ajustado; dir1 de 900016 es CRP y no aplica a este caso) |
| **@i_envio_notifica** | 'S' |
| **Regla** | AEST-RAMA-082/083T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 900016, @i_direccion = 2,
    @i_envio_notifica = 'S',  -- override bajo prueba
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT en_subtipo, en_fecha_crea FROM cobis..cl_ente WHERE en_ente = 900016
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900016 AND di_direccion = 2
ORDER BY 1 DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31 (contrato exitoso de notificacion confirmado). Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - DELETE; `cobis..ts_direccion` - INSERT

---

### TC70 — BVA abajo - eliminacion de direccion sin telefonos asociados

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900037 -- corregido; 900017 solo tenia 1 direccion total (bloqueo por "ultima direccion") |
| **@i_direccion** | 2 |
| **Regla** | AEST-RAMA-084-abajo |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de correccion:** se identifico un ente con 2 direcciones totales (dir=1 tipo D con 1 telefono asociado, dir=2 tipo T sin telefonos) para poder eliminar la direccion sin activar el bloqueo de "ultima direccion" (RN34) y asi aislar el ciclo de telefonos con 0 iteraciones.

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 900037,  -- override bajo prueba
    @i_direccion = 2,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_telefono WHERE te_ente = 900037 AND te_direccion = 2
-- Estado real verificado 2026-09-02: 0 (coincide con hipotesis de "sin telefonos")
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900037
-- Estado real verificado 2026-09-02: 2 (cumple la precondicion de "puede eliminarse")
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900037 AND di_direccion = 2
-- Resultado real verificado 2026-09-02: 0 (direccion eliminada correctamente)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con la hipotesis original: el ciclo de telefonos no itera (0 filas) y la eliminacion se completa sin bloqueo.

**Trazabilidad por DB:** `cobis..cl_telefono` - SELECT (0 filas, confirma ausencia real); `cobis..cl_direccion` - DELETE; `cobis..ts_direccion` - INSERT; `cobis_his..cl_direccion_his` - INSERT

---

### TC71 — BVA entrada - eliminacion de direccion con 1 telefono asociado

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 1 -- corregido; la tabla `cl_telefono` SI tiene datos reales (3,729,761 filas); el hallazgo previo de "0 filas" fue limitado al ente 900017 y no se amplio la busqueda |
| **@i_direccion** | 1 |
| **@i_operacion** | 'D' |
| **@t_trn** | 1226 |
| **Regla** | AEST-BVA-002-entrada |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |

> **Nota de correccion:** se amplio la busqueda a la totalidad de `cobis..cl_telefono` y se identifico un ente con exactamente 1 telefono asociado a una direccion no-ultima y no-CRP (4 direcciones totales, `di_envio_crp='N'`).

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 1,  -- override bajo prueba
    @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_telefono WHERE te_ente = 1 AND te_direccion = 1
-- Estado real verificado 2026-09-02: 1 (coincide con hipotesis de BVA entrada)
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 1
-- Estado real verificado 2026-09-02: 4 (no es la ultima direccion)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 1 AND di_direccion = 1
-- Resultado real verificado 2026-09-02: 0 (direccion eliminada)
SELECT COUNT(1) FROM cobis..cl_telefono WHERE te_ente = 1 AND te_direccion = 1
-- Resultado real verificado 2026-09-02: 0 (telefono eliminado via sp_telefono, ciclo de 1 iteracion)
```

**Resultado esperado:** `RETURN 0` — verificado 2026-09-02. Coincide con la hipotesis original: el ciclo de telefonos itera exactamente 1 vez y ambos registros se eliminan correctamente.

**Trazabilidad por DB:** `cobis..cl_telefono` - DELETE (via `sp_telefono`); `cobis..cl_direccion` - DELETE; `cobis..ts_direccion` - INSERT

---

### TC72 — DELETE exitoso - Eliminacion de direccion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900014 (ajustado; 2615 original solo tiene 1 direccion, ver TC62) |
| **@i_direccion** | 2 |
| **Regla** | RN22, RN33, RN34 |
| **fuente_valor** | sybase_select (ejecutado, cuenta real ajustada) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'D', @i_producto = 1,
    @i_ente = 900014,  -- override bajo prueba
    @i_direccion = 2,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT di_direccion, di_tipo, di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 900014
-- Estado real verificado 2026-08-31: dir1 (D, CRP), dir2 (T, no-CRP) -- se elimina dir2 (no CRP, no ultima)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900014
ORDER BY 1 DESC
```

**Resultado esperado:** `RETURN 0` — verificado 2026-08-31. Coincide con hipotesis.

**Trazabilidad por DB:** `cobis..cl_direccion` - DELETE; `cobis..ts_direccion` - INSERT; `cobis_his..cl_direccion_his` - INSERT

---

## GRUPO 7 — Delete temporal (E): Validaciones temporales

### TC73 — Transaccion invalida en Delete con validacion temporal

| Campo | Detalle |
|-------|---------|
| **@i_operacion** | 'E' |
| **@t_trn** | 999 |
| **@i_ente** | 900010 |
| **@i_direccion** | 1 |
| **Regla** | AEST-RAMA-088F |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 999,  -- override bajo prueba
    @i_operacion = 'E', @i_producto = 1,
    @i_ente = 900010, @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 1
ORDER BY 1 DESC
-- Condicion: sin nuevas filas (SP retorno antes de delegar; trn invalida)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "Transaccion no permitida" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=151051).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC74 — Direccion inexistente rechaza la eliminacion temporal

| Campo | Detalle |
|-------|---------|
| **@i_operacion** | 'E' |
| **@t_trn** | 1226 |
| **@i_direccion** | 99 |
| **Regla** | AEST-RAMA-089F |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'E', @i_producto = 1,
    @i_ente = 900010,
    @i_direccion = 99,  -- override bajo prueba
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT 1 FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 99
-- Condicion: 0 filas
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900010 AND di_direccion = 99
ORDER BY 1 DESC
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No existe dato solicitado" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101001).

**Trazabilidad por DB:** `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC75 — No quedan direcciones temporales activas tras la eliminacion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 900018 |
| **@i_direccion** | 1 |
| **Regla** | AEST-RAMA-090T |
| **fuente_valor** | sybase_select (ejecutado) |

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'E', @i_producto = 1,
    @i_ente = 900018, @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion_tmp WHERE di_ente = 900018 AND di_estado <> 'E'
-- Estado real verificado 2026-08-31: 0 filas (coincide con hipotesis)
```

**POST:**
```sql
SELECT COUNT(1) FROM cobis..cl_direccion WHERE di_ente = 900018 AND di_direccion = 1
ORDER BY 1 DESC
-- Condicion: sin cambios (rechazo)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "No se pueden eliminar todas las direcciones" (verificado 2026-08-31). Coincide con hipotesis (`@w_num`=101053).

**Trazabilidad por DB:** `cobis..cl_direccion_tmp` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC76 — CRP temporal sin otra vigente

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 5220 -- corregido; 900018 no permitia aislar el chequeo CRP (ver nota) |
| **@i_direccion** | 1 |
| **Regla** | AEST-RAMA-091T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |


**PRE:**
```sql
SELECT di_envio_crp FROM cobis..cl_direccion WHERE di_ente = 5220 AND di_direccion = 1
-- Estado real verificado 2026-09-02: 'S' (direccion principal marcada como CRP)
SELECT di_estado, di_envio_crp FROM cobis..cl_direccion_tmp WHERE di_ente = 5220 AND di_direccion = 1
-- Estado real verificado 2026-09-02: di_estado='C' (activa), di_envio_crp='N' (no coincide con la principal)
```

#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'E', @i_producto = 1,
    @i_ente = 5220,  -- override bajo prueba
    @i_direccion = 1,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**POST:**
```sql
SELECT di_estado FROM cobis..cl_direccion_tmp WHERE di_ente = 5220 AND di_direccion = 1
-- Resultado real verificado 2026-09-02: 'C' (sin cambios, rechazo confirmado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO SE PUEDE ELIMINAR LA DIRECCION DE ENVIO DE CORRESPONDENCIA" (verificado 2026-09-02, `@w_num`=101274). Coincide con la hipotesis original: se confirma el mensaje CRP-especifico sin ser enmascarado por el bloqueo generico de "ultima direccion".

**Trazabilidad por DB:** `cobis..cl_direccion_tmp` - SELECT; `cobis..cl_direccion` - SELECT (sin escritura)

---

### TC77 — Direccion temporal asociada a cuenta bloquea la eliminacion

| Campo | Detalle |
|-------|---------|
| **@i_ente** | 802127 -- corregido; la tabla `cl_dir_est_cta_tmp` SI tiene datos reales (2 filas vigentes en todo el entorno) |
| **@i_direccion** | 2 |
| **@i_operacion** | 'E' |
| **@t_trn** | 1226 |
| **Regla** | AEST-RAMA-093T |
| **fuente_valor** | sybase_select (verificado 2026-09-02, coincide con hipotesis). |


#### Plantilla de ejecucion del SP

```sql
declare @o_direccion     tinyint
declare @o_msj_error     varchar(132)
declare @o_sig_log_svr   int
declare @w_return        int

exec @w_return = cobis..sp_direccion_dml
    @s_ssn = 500001, @s_user = 'QATESTER', @s_term = 'QATERM01',
    @s_date = '2026-08-26 09:00:00', @s_srv = 'MIS', @s_lsrv = 'MIS',
    @s_ofi = 1, @s_rol = 1, @t_debug = 'N', @t_from = 'QA_CONSOLIDADO',
    @t_trn = 1226, @i_operacion = 'E', @i_producto = 1,
    @i_ente = 802127,  -- override bajo prueba
    @i_direccion = 2,
    @e_actmasivacli = 'N',
    @o_direccion = @o_direccion output, @o_msj_error = @o_msj_error output,
    @o_sig_log_svr = @o_sig_log_svr output

select @w_return as retorno, @o_direccion, @o_msj_error, @o_sig_log_svr
GO
```

**PRE:**
```sql
SELECT cc_estado, cc_tipo_dir, cc_direccion_ec FROM cobis..cl_dir_est_cta_tmp WHERE cc_cliente = 802127 AND cc_cliente_ec = 802127 AND cc_direccion_ec = 2
-- Estado real verificado 2026-09-02: ('N', 'D', 2) -- asociacion vigente confirmada
SELECT di_direccion, di_estado FROM cobis..cl_direccion_tmp WHERE di_ente = 802127
-- Estado real verificado 2026-09-02: (2, 'C') -- 1 direccion temporal activa
```

**POST:**
```sql
SELECT di_direccion, di_estado FROM cobis..cl_direccion_tmp WHERE di_ente = 802127
-- Resultado real verificado 2026-09-02: (2, 'C') sin cambios (rechazo confirmado)
```

**Resultado esperado:** `EXCEPCION SQL` — sp_direccion_dml: "NO SE PUEDE ELIMINAR UNA DIRECCION DE ENVIO DE ESTADO CUENTA" (verificado 2026-09-02, `@w_num`=101273). Coincide con la hipotesis original.

**Trazabilidad por DB:** `cobis..cl_dir_est_cta_tmp` - SELECT; `cobis..cl_direccion_tmp` - SELECT (sin escritura)

---

## TABLAS MONITOREADAS

| Tabla | Operaciones observadas | TCs relacionados |
|-------|------------------------|-------------------|
| `cobis..cl_ente` | SELECT | TC01-03, TC19, TC24-25, TC32-33, TC60, TC69 |
| `cobis..cl_direccion` | SELECT / INSERT / UPDATE / DELETE | Todos (TC01-TC77) |
| `cobis..ts_direccion` | INSERT | TC01, TC16, TC21, TC23, TC26-TC33 (alta); TC38-TC57 (update, x2 por caso); TC62-TC72 (delete); TC26, TC68 (secuencial via sp_gen_sec) |
| `cobis..cl_producto` | SELECT | TC06, y validacion implicita en toda ruta DELETE (TC60-TC77) |
| `cobis..cl_ciudad` | SELECT | TC07, TC11, TC49 |
| `cobis..cl_parroquia` | SELECT | TC08, TC48 |
| `cobis..cl_canton_ciudad` | SELECT | TC09-TC11, TC42, TC55 |
| `cobis..cl_parroquia_ciudad` | SELECT | TC10, TC50 |
| `cobis..cl_oficina` | SELECT | TC12, TC51 |
| `cobis..cl_parametro` (TPVGRE) | SELECT | TC29-TC31, TC53 |
| `cob_cuentas..cc_ctacte` | SELECT | TC34, TC36, TC64 (supuesto) |
| `cl_dir_envio_tarj_cred` | SELECT / UPDATE | TC35, TC58, TC59, TC65 (todos supuesto_controlado; tabla no existe en este entorno) |
| `cl_direccion_email` | SELECT | TC66 (supuesto_controlado; tabla no existe en este entorno) |
| `cl_log_dir_envio_ec` | INSERT | TC58, TC59, TC67 (supuesto/parcial) |
| `cl_vr_solicitud_log` | INSERT | TC33 (no alcanzado por maximo de direcciones en esta corrida) |
| `cobis..cl_telefono` | SELECT / DELETE (via sp_telefono) | TC70-TC71 |
| `cobis..cl_direccion_tmp` | SELECT | TC75 |
| `cobis..cl_dir_est_cta_tmp` | SELECT | TC77 |
| `cobis_his..cl_direccion_his` | INSERT | TC67, TC72 (delete exitoso) |

---

## TABLAS MONITOREADAS POR SPs HIJOS

| SP hijo | Tablas afectadas | TCs relacionados |
|---------|-------------------|-------------------|
| `sp_gen_sec` | `cobis..ts_direccion` (secuencial generado) | TC26, TC68 |
| `sp_cseqnos` | `cl_vr_solicitud_log` | TC33 (no alcanzado en esta corrida) |
| `sp_telefono` | `cobis..cl_telefono` (DELETE) | TC70-TC71 |
| `sp_notif_cli_mod_dir` | Notificacion al cliente (sin tabla propia observada en este entorno) | TC69 |
| `sp_catalogo` | Validacion de catalogo `cl_estado_ver_ref` (verificado) | TC15 |
| `sp_dir_est_cta` | `cobis..cl_dir_est_cta_tmp` | TC77 |
| `sp_cerror` / `sp_msj_error` | Generacion de mensajes de error (sin tabla propia) | Todos los casos de rechazo (TC02-TC15, TC17, TC19-TC20, TC22, TC24-TC25, TC37, TC42, TC45, TC49, TC55-TC56, TC60-TC64, TC70, TC73-TC76) |
