## Que hace este SP
Este SP orquesta la transaccion de deposito en cuenta corriente para multiples canales (VEN, CNB, ATM, WAP, SAT), valida precondiciones operativas y regulatorias (estado de canal, estado de cuenta, bloqueos, deposito inicial, validacion de codigo/origen, cupos), enruta entre ejecucion local/remota y delega la contabilizacion al SP hijo principal. En escenarios de inhabilitacion SBS realiza cierre transaccional de la cuenta y registra trazas historicas; en errores funcionales/tecnicos retorna codigos especificos y actualiza estados de consulta automatica.

================================================================================
ANALISIS ESTRUCTURAL  - SP: sp_tr_deposito_rc
================================================================================
| Campo | Valor |
|-------|-------|
| Archivo fuente | trdep_rc.sp |
| analyzer_version | 2.0 |
| Fecha | 2026-10-02 |
| LOC efectivas | 929 |
| loc_cuerpo_proc | 1289 |
| tipo_sp | ORQUESTADOR |
| complejidad_final | CRITICA |
| casos_brutos | 206 |
| casos_finales_estimados | 148 |

--- MAPA DE REGIONES ---
| Rango | Tipo | Nota |
|-------|------|------|
| L1-L132 | COMENTARIO_BLOQUE | Encabezado historico, proposito y bitacora de modificaciones |
| L133-L134 | FUERA_CUERPO_PRE | `use cob_cuentas` |
| L135 | DELIMITADOR_GO | Separador de lote previo a DROP |
| L136-L146 | FUERA_CUERPO_PRE | Bloque de DROP condicional del SP |
| L147-L228 | SIGNATURA | `create proc` y firma completa de parametros |
| L229-L1517 | CUERPO_ACTIVO | Declaraciones, validaciones, enrutamiento y ejecucion |
| L1518 | DELIMITADOR_GO | Cierre del procedimiento |
| L1519-L1524 | FUERA_CUERPO_POST | Verificacion de CREATE |
| L1525 | DELIMITADOR_GO | Fin de script |

--- PARAMETROS ---
| # | nombre | tipo | longitud | direccion | default | obligatorio | rol_en_sp | lineas_uso |
|---|--------|------|----------|-----------|---------|-------------|-----------|------------|
| 1 | @s_ssn | int | - | ENTRADA | null | Si | CONTEXTO | 319, 1373, 1480 |
| 2 | @s_srv | varchar | 30 | ENTRADA | null | Si | PASANTE | 443, 1115, 1207 |
| 3 | @s_lsrv | varchar | 30 | ENTRADA | null | Si | PASANTE | 444, 947, 991 |
| 4 | @s_user | varchar | 30 | ENTRADA | null | Si | DISCRIMINADOR | 322, 444, 1481 |
| 5 | @s_sesn | int | - | ENTRADA | null | No | PASANTE | 445, 1117, 1482 |
| 6 | @s_term | varchar | 10 | ENTRADA | null | Si | PASANTE | 446, 1113, 1483 |
| 7 | @s_date | datetime | - | ENTRADA | null | Si | PASANTE | 343, 584, 1484 |
| 8 | @s_ofi | smallint | - | ENTRADA | null | Si | DISCRIMINADOR | 363, 447, 982 |
| 9 | @s_rol | smallint | - | ENTRADA | null | Si | PASANTE | 448, 1111, 1485 |
| 10 | @s_org_err | char | 1 | ENTRADA | null | No | DISCRIMINADOR | 368 |
| 11 | @s_error | int | - | ENTRADA | null | No | PASANTE | 375, 428 |
| 12 | @s_sev | tinyint | - | ENTRADA | null | No | PASANTE | 376, 449 |
| 13 | @s_msg | mensaje | - | ENTRADA | null | No | PASANTE | 377, 450 |
| 14 | @s_org | char | 1 | ENTRADA | null | Si | DISCRIMINADOR | 437, 1118, 1181 |
| 15 | @t_corr | char | 1 | ENTRADA | 'N' | No | DISCRIMINADOR | 338, 719, 992 |
| 16 | @t_ssn_corr | int | - | ENTRADA | null | No | PASANTE | 341, 1214, 1377 |
| 17 | @t_debug | char | 1 | ENTRADA | 'N' | No | CONTEXTO | 349, 1208, 1509 |
| 18 | @t_file | varchar | 14 | ENTRADA | null | No | CONTEXTO | 350, 1209, 1510 |
| 19 | @t_from | varchar | 32 | ENTRADA | null | No | PASANTE | 589, 1215, 1410 |
| 20 | @t_rty | char | 1 | ENTRADA | 'N' | No | PASANTE | 457, 1129, 1211 |
| 21 | @t_trn | int | - | ENTRADA | null | Si | DISCRIMINADOR | 454, 818, 1189 |
| 22 | @p_lssn | int | - | ENTRADA | null | No | PASANTE | 1413 |
| 23 | @p_rssn | int | - | ENTRADA | null | No | PASANTE | 1217, 1414 |
| 24 | @p_rssn_corr | int | - | ENTRADA | null | No | PASANTE | 1218, 1415 |
| 25 | @p_slddisp | money | - | ENTRADA | null | No | SALIDA | 1494 |
| 26 | @p_sldcont | money | - | ENTRADA | null | No | SALIDA | 1493 |
| 27 | @p_nombre | varchar | 30 | ENTRADA | null | No | SALIDA | 1495 |
| 28 | @p_envio | char | 1 | ENTRADA | 'N' | No | SALIDA | 1374 |
| 29 | @p_rpta | char | 1 | ENTRADA | 'N' | No | SALIDA | 1491 |
| 30 | @i_cta | cuenta | - | ENTRADA | null | Si | DISCRIMINADOR | 420, 491, 1417 |
| 31 | @i_efe | money | - | ENTRADA | null | Si | DISCRIMINADOR | 720, 902, 1051 |
| 32 | @i_prop | money | - | ENTRADA | 0 | No | PASANTE | 1221, 1419 |
| 33 | @i_loc | money | - | ENTRADA | null | Si | DISCRIMINADOR | 720, 903, 1051 |
| 34 | @i_plaz | money | - | ENTRADA | 0 | No | PASANTE | 1223, 1421 |
| 35 | @i_mon | tinyint | - | ENTRADA | null | Si | DISCRIMINADOR | 454, 556, 1011 |
| 36 | @i_sp | char | 1 | ENTRADA | 'N' | No | DISCRIMINADOR | 840, 882, 1423 |
| 37 | @i_tsn | int | - | ENTRADA | null | No | PASANTE | 1085, 1226, 1425 |
| 38 | @i_autoriza | char | 1 | ENTRADA | 'N' | No | DISCRIMINADOR | 1011 |
| 39 | @i_codigo | char | 30 | ENTRADA | null | No | DISCRIMINADOR | 383, 420, 1133 |
| 40 | @i_empresa | varchar | 6 | ENTRADA | null | No | PASANTE | 1134, 1246, 1428 |
| 41 | @i_des_cli | varchar | 30 | ENTRADA | null | No | PASANTE | 1242, 1429 |
| 42 | @i_factura | varchar | 15 | ENTRADA | null | No | DISCRIMINADOR | 325, 1192, 1393 |
| 43 | @i_cant_chq | int | - | ENTRADA | null | No | PASANTE | 1082, 1131, 1439 |
| 44 | @i_ubi | int | - | ENTRADA | null | No | PASANTE | 456, 1083, 1440 |
| 45 | @o_nombre | varchar | 30 | SALIDA | null | No | SALIDA | 1289, 1479 |
| 46 | @o_impuesto | money | - | SALIDA | null | No | SALIDA | 1290, 1480 |
| 47 | @o_neto | money | - | SALIDA | null | No | SALIDA | 1291, 1481 |
| 48 | @o_ssn | int | - | SALIDA | 0 | No | SALIDA | 319 |
| 49 | @o_consulta | int | - | SALIDA | 0 | No | SALIDA | 370, 1165, 1359 |
| 50 | @i_ssn | int | - | ENTRADA | null | No | DISCRIMINADOR | 1062, 1318 |
| 51 | @i_date_off | datetime | - | ENTRADA | null | No | PASANTE | 458, 1137, 1441 |
| 52 | @i_canal | varchar | 5 | ENTRADA | 'VEN' | No | DISCRIMINADOR | 322, 556, 1143 |
| 53 | @i_aplcobis | char | 1 | ENTRADA | 'S' | No | DISCRIMINADOR | 496, 560, 705 |
| 54 | @i_ruta_transito | varchar | 30 | ENTRADA | null | No | CONTEXTO | 394 (comentado) |
| 55 | @i_nomb_dep | varchar | 24 | ENTRADA | null | No | PASANTE | 1197, 1260, 1450 |
| 56 | @e_cds | char | 1 | ENTRADA | null | No | PASANTE | 1263, 1453 |
| 57 | @o_novedad_sbs | char | 1 | SALIDA | 'N' | No | SALIDA | 316, 702 |
| 58 | @o_msg_error | varchar | 132 | SALIDA | null | No | SALIDA | 315, 715 |
| 59 | @o_fecha_contable | varchar | 10 | SALIDA | null | No | SALIDA | 1265, 1455 |
| 60 | @i_iden_dep | varchar | 13 | ENTRADA | null | No | DISCRIMINADOR | 325, 1200, 1394 |
| 61 | @i_debito | money | - | ENTRADA | null | No | PASANTE | 1266, 1456 |
| 62 | @i_val_consep | char | 1 | ENTRADA | null | No | PASANTE | 1267 |
| 63 | @i_denominaciones | varchar | 250 | ENTRADA | '' | No | PASANTE | 1268, 1457 |
| 64 | @e_cod_trx | int | - | ENTRADA | 0 | No | PASANTE | 1269, 1458 |
| 65 | @e_verde | char | 1 | ENTRADA | 'N' | No | PASANTE | 1270, 1459 |
| 66 | @e_uuid | varchar | 255 | ENTRADA | '' | No | PASANTE | 1271, 1460 |
| 67 | @o_servicio_not | varchar | 5 | SALIDA | null | No | SALIDA | 1273, 1462 |
| 68 | @o_cod_ente | varchar | 20 | SALIDA | null | No | SALIDA | 1274, 1463 |
| 69 | @o_celular | varchar | 10 | SALIDA | null | No | SALIDA | 1275, 1464 |
| 70 | @o_correo | varchar | 64 | SALIDA | null | No | SALIDA | 1276, 1465 |
| 71 | @o_valor | varchar | 11 | SALIDA | null | No | SALIDA | 1277, 1466 |
| 72 | @o_valor1 | varchar | 11 | SALIDA | null | No | SALIDA | 1278, 1467 |
| 73 | @o_prod_deb | char | 3 | SALIDA | null | No | SALIDA | 1279, 1468 |
| 74 | @o_cta_lat | char | 3 | SALIDA | null | No | SALIDA | 1280, 1469 |

--- RAMAS DE CONTROL ---
| id | linea | tipo | condicion | rama_testeable | motivo_exclusion | variables_evaluadas |
|----|-------|------|-----------|----------------|------------------|---------------------|
| RAMA-001 | 322 | IF | @i_canal = 'CNB' and @s_user != 'cnb001' | SI | ENRUTAMIENTO_PRINCIPAL_CANAL | @i_canal,@s_user |
| RAMA-002 | 332 | IF | @@rowcount = 0 | SI |  | @@rowcount |
| RAMA-003 | 335 | IF | @v_estado_canal != 'A' | SI |  | @v_estado_canal |
| RAMA-004 | 338 | IF | @t_corr = 'S' | SI |  | @t_corr |
| RAMA-005 | 340 | IF_EXISTS | exists cc_tran_monet duplicado CNB | SI |  | @t_ssn_corr,@s_date |
| RAMA-006 | 362 | IF | @i_canal = 'CNB' | SI |  | @i_canal |
| RAMA-007 | 368 | IF | @s_org_err is not null | SI |  | @s_org_err |
| RAMA-008 | 383 | IF | @i_codigo is null | SI |  | @i_codigo |
| RAMA-009 | 416 | IF_EXISTS | cuenta requiere referencia | SI |  | @i_cta |
| RAMA-010 | 422 | IF | (@i_codigo = null and @t_corr = 'N') | SI | riesgo de bug por comparacion a null | @i_codigo,@t_corr |
| RAMA-011 | 437 | IF | @s_org = 'U' and @i_canal ='VEN' | SI |  | @s_org,@i_canal |
| RAMA-012 | 461 | IF | @w_return != 0 | SI |  | @w_return |
| RAMA-013 | 493 | IF | @@rowcount = 0 | SI |  | @@rowcount |
| RAMA-014 | 496 | IF | @i_aplcobis='S' | SI |  | @i_aplcobis |
| RAMA-015 | 508 | IF | @w_estado = 'T' | SI |  | @w_estado |
| RAMA-016 | 527 | IF | @@rowcount != 0 | SI |  | @@rowcount |
| RAMA-017 | 540 | IF | @i_aplcobis ='S' | SI |  | @i_aplcobis |
| RAMA-018 | 550 | ELSE | else de validacion bloqueo | SI |  | @i_aplcobis |
| RAMA-019 | 556 | IF | @i_canal ='ATM' and @i_mon = 17 | SI |  | @i_canal,@i_mon |
| RAMA-020 | 560 | IF | @i_aplcobis ='S' | SI |  | @i_aplcobis |
| RAMA-021 | 570 | ELSE | else de validacion ATM-EUR | SI |  | @i_aplcobis |
| RAMA-022 | 579 | IF | @w_estado = 'D' | SI |  | @w_estado |
| RAMA-023 | 600 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-024 | 608 | IF | existe inhabilidad titular/firma | SI | regla regulatoria SBS | @w_existe_inhab,@w_titular_inh,@w_otros_firmantes,@w_firmante_inh |
| RAMA-025 | 617 | IF | @@error <> 0 or @@rowcount <> 1 | SI |  | @@error,@@rowcount |
| RAMA-026 | 636 | IF | @@error <> 0 or @@rowcount <> 1 | SI |  | @@error,@@rowcount |
| RAMA-027 | 665 | IF | @@error != 0 | SI |  | @@error |
| RAMA-028 | 687 | IF | @@error != 0 | SI |  | @@error |
| RAMA-029 | 705 | IF | @i_aplcobis = 'N' | SI |  | @i_aplcobis |
| RAMA-030 | 719 | IF | @t_corr = 'N' | SI |  | @t_corr |
| RAMA-031 | 730 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-032 | 753 | IF_EXISTS | codigo afecta BCE activo | SI |  | @i_codigo |
| RAMA-033 | 759 | IF_EXISTS | origen no permitido para codigo | SI |  | @w_tabla_valida,@w_origen_cta |
| RAMA-034 | 776 | IF_EXISTS | origen en tabla de validacion | SI |  | @w_tabla_valida,@w_origen_cta |
| RAMA-035 | 783 | IF | @w_origen_cta in ('6','21') | SI |  | @w_origen_cta |
| RAMA-036 | 794 | IF_EXISTS | codigo no asociado a origen | SI |  | @i_codigo |
| RAMA-037 | 820 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-038 | 823 | IF | @i_aplcobis ='S' | SI |  | @i_aplcobis |
| RAMA-039 | 837 | IF_EXISTS | cuenta en catalogo de deposito especial | SI |  | @i_cta,@i_sp |
| RAMA-040 | 863 | IF | @w_permite = 'N' | SI |  | @w_permite |
| RAMA-041 | 876 | ELSE | ruta no especial | SI |  | @w_empresa |
| RAMA-042 | 882 | IF | @w_empresa > 0 and @i_sp = 'N' | SI |  | @w_empresa,@i_sp |
| RAMA-043 | 884 | IF_EXISTS | empresa catalogada como dep especial | SI |  | @w_empresa |
| RAMA-044 | 911 | IF | @w_return != 0 | SI |  | @w_return |
| RAMA-045 | 923 | ELSE | conversion exitosa | SI |  | @w_return |
| RAMA-046 | 928 | IF | @w_moneda_cta <> 0 | SI |  | @w_moneda_cta |
| RAMA-047 | 940 | IF | @i_canal ='VEN' | SI | ENRUTAMIENTO_PRINCIPAL_OFICINA_TIPO | @i_canal |
| RAMA-048 | 955 | IF | @w_return != 0 | SI |  | @w_return |
| RAMA-049 | 974 | IF | @w_return != 0 | SI |  | @w_return |
| RAMA-050 | 980 | ELSE | rama no VEN | SI |  | @i_canal |
| RAMA-051 | 988 | IF | @w_tipo = 'L' | SI | ENRUTAMIENTO_PRINCIPAL_LOCAL_REMOTO | @w_tipo |
| RAMA-052 | 992 | IF | @t_corr = 'N' | SI |  | @t_corr |
| RAMA-053 | 994 | ELSE | factor correccion | SI |  | @t_corr |
| RAMA-054 | 1011 | IF | @i_autoriza='N' and @i_mon=1 and @t_corr='N' | SI |  | @i_autoriza,@i_mon,@t_corr |
| RAMA-055 | 1027 | IF | excede maximo/minimo y moneda caja 0 | SI |  | @w_maximo_p,@w_minimo_p,@i_efe,@i_loc,@w_moneda_caja |
| RAMA-056 | 1032 | IF | @i_aplcobis='S' | SI |  | @i_aplcobis |
| RAMA-057 | 1051 | IF | @i_efe > 0 and @t_corr = 'N' | SI |  | @i_efe,@t_corr |
| RAMA-058 | 1060 | IF | @i_canal ='VEN' | SI |  | @i_canal |
| RAMA-059 | 1062 | IF | @i_ssn = 0 | SI |  | @i_ssn |
| RAMA-060 | 1089 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-061 | 1143 | IF | @i_canal = 'CNB' | SI |  | @i_canal |
| RAMA-062 | 1148 | IF | @v_valida_cupo > @w_cupo_cli | SI |  | @v_valida_cupo,@w_cupo_cli |
| RAMA-063 | 1162 | IF | @i_canal = 'CNB' | SI |  | @i_canal |
| RAMA-064 | 1168 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-065 | 1181 | IF | @s_org='U' or @s_org='D' | SI | ENRUTAMIENTO_PRINCIPAL_ORIGEN | @s_org |
| RAMA-066 | 1184 | IF | @w_tipo = 'L' | SI |  | @w_tipo |
| RAMA-067 | 1189 | IF | @t_trn in (3040,3288,3553,3289,4435) | SI |  | @t_trn |
| RAMA-068 | 1194 | IF | @i_canal in ('WAP','SAT') | SI |  | @i_canal |
| RAMA-069 | 1199 | ELSE | identificacion desde @i_iden_dep | SI |  | @i_canal |
| RAMA-070 | 1302 | IF | @t_trn in (...) | SI |  | @t_trn |
| RAMA-071 | 1318 | IF | @i_ssn is not null and retorno invalido y canal VEN | SI |  | @i_ssn,@w_return_2,@i_canal |
| RAMA-072 | 1342 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-073 | 1358 | IF | @w_return_2 <> 0 and @w_return_2 <> 1 | SI |  | @w_return_2 |
| RAMA-074 | 1370 | IF | @w_tipo = 'R' | SI |  | @w_tipo |
| RAMA-075 | 1385 | IF | @s_org = 'S' | SI |  | @s_org |
| RAMA-076 | 1387 | IF | @w_tipo = 'L' | SI |  | @w_tipo |
| RAMA-077 | 1391 | IF | @t_trn in (...) | SI |  | @t_trn |
| RAMA-078 | 1475 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-079 | 1489 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-080 | 1499 | IF | @w_return <> 0 | SI |  | @w_return |
| RAMA-081 | 1504 | IF | @w_tipo = 'R' | SI |  | @w_tipo |

--- CODIGO INALCANZABLE ---
| id | linea_condicion | condicion | variable | linea_asignacion | valor_asignado | clasificacion | motivo |
|----|-----------------|-----------|----------|------------------|----------------|---------------|--------|
| INA-01 | 422 | @i_codigo = null | @i_codigo | 383 | lookup catalogo | REVISION_MANUAL | Comparacion a NULL con `=` en Sybase puede dejar rama sin efecto esperado; requiere validacion funcional/manual |
| INA-02 | 394 | bloque Ref038 comentado | @i_ruta_transito | n/a | n/a | REVISION_MANUAL | Bloque completo comentado, no ejecutable en runtime |

--- SPs DEPENDIENTES ---
| id | sp | clasificacion | veces_invocado | lineas | parametros_clave | retornos_conocidos | requiere_contrato |
|----|-----|---------------|----------------|--------|------------------|--------------------|-------------------|
| DEP-01 | cobis..sp_cerror | UTILITARIO | 16 | 348,371,425,498,510,542,562,621,641,669,692,765,800,866,891,914,1034,1092,1150,1345,1507 | @i_num,@i_msg | codigos propagados por return del padre | NO |
| DEP-02 | cob_remesas..sp_verifica_caja_rc | LIBRERIA_NEGOCIO | 1 | 440 | contexto caja/canal/oficina | 0 / !=0 | SI |
| DEP-03 | cob_cuentas..sp_verifica_inhabilitacion_sbs | LIBRERIA_NEGOCIO | 1 | 584 | @i_cta_banco,@s_date | 0 / !=0 | SI |
| DEP-04 | cobis..sp_cseqnos | UTILITARIO | 1 | 651 | @i_tabla='cc_his_cierre' | 0 / !=0 | NO |
| DEP-05 | cobis..sp_error | UTILITARIO | 1 | 707 | @i_num=30018 | mensaje controlado | NO |
| DEP-06 | cob_sbancario..sp_sb_valida_dep_inicial | LIBRERIA_NEGOCIO | 1 | 723 | producto=3, cuenta, monto | 0 / !=0 | SI |
| DEP-07 | cob_cuentas..sp_val_ctas_rotativas | LIBRERIA_NEGOCIO | 1 | 817 | @i_cta,@i_trn | 0 / !=0 | SI |
| DEP-08 | db_biz_admempresa..sp_con_parametroconf | LIBRERIA_NEGOCIO | 1 | 856 | empresa/producto/servicio | booleano en OUT | SI |
| DEP-09 | cob_cuentas..sp_convierte_valor | LIBRERIA_NEGOCIO | 1 | 902 | monto/moneda/cuenta | 0 / !=0 | SI |
| DEP-10 | cobis..sp_parametros | UTILITARIO | 1 | 945 | producto+servidor | 0 / !=0 | NO |
| DEP-11 | cob_cuentas..sp_cta_origen | LIBRERIA_NEGOCIO | 1 | 963 | @i_cta,@i_mon | tipo L/R | SI |
| DEP-12 | cob_cuentas..sp_cons_automatica_rc | LIBRERIA_NEGOCIO | 2 | 1067,1322 | operacion/status consulta | 0 / !=0 | SI |
| DEP-13 | cobis..sp_verificacion_deposito_rc | LIBRERIA_NEGOCIO | 1 | 1108 | cliente/cuenta/montos/canal | 0 / !=0 | SI |
| DEP-14 | cob_cuentas..sp_tr_depo2_local_remoto_rc | LIBRERIA_NEGOCIO | 2 | 1205,1397 | operacion deposito completa | 0,1,!=0 | SI |
| DEP-15 | cobis..sp_begin_secure_submit | UTILITARIO | 1 | 1372 | @i_toserver | 0 / !=0 | NO |
| DEP-16 | cobis..sp_end_secure_submit | UTILITARIO | 1 | 1378 | @i_wait='S' | 0 / !=0 | NO |
| DEP-17 | cobis..sp_begin_resubmit | UTILITARIO | 1 | 1484 | toserver/touser/tosesion | 0 / !=0 | NO |
| DEP-18 | cobis..sp_end_resubmit | UTILITARIO | 1 | 1497 | payload respuesta | 0 / !=0 | NO |

--- CONTRATO DE LIBRERIA POR SP HIJO ---
| id_contrato | sp_hijo | escenario | retorno_simulado | comportamiento_esperado_padre |
|-------------|---------|-----------|------------------|-------------------------------|
| CTR-01 | cob_remesas..sp_verifica_caja_rc | Exito | 0 | Continua validaciones de cuenta |
| CTR-02 | cob_remesas..sp_verifica_caja_rc | Error de negocio | 31xxx | Retorna @w_return y corta flujo |
| CTR-03 | cob_remesas..sp_verifica_caja_rc | Error tecnico | @@error | Marca @o_consulta=0 y retorna error |
| CTR-04 | cob_remesas..sp_verifica_caja_rc | OUTs en NULL | n/a | No aplica (sin OUT criticos) |
| CTR-05 | cob_remesas..sp_verifica_caja_rc | Integridad pasantes | n/a | Debe recibir @s_org,@i_mon,@i_cta sin transformacion |
| CTR-06 | cob_cuentas..sp_verifica_inhabilitacion_sbs | Exito | 0 | Evalua reglas SBS y puede cerrar cuenta |
| CTR-07 | cob_cuentas..sp_verifica_inhabilitacion_sbs | Error de negocio | !=0 | Retorno inmediato de error |
| CTR-08 | cob_cuentas..sp_verifica_inhabilitacion_sbs | Error tecnico | @@error | Abort flujo de deposito inicial |
| CTR-09 | cob_cuentas..sp_verifica_inhabilitacion_sbs | OUTs en NULL | 0 con OUT nulos | No debe cerrar cuenta por falso positivo |
| CTR-10 | cob_cuentas..sp_verifica_inhabilitacion_sbs | Integridad pasantes | n/a | Debe propagar @i_cta,@s_date |
| CTR-11 | cob_sbancario..sp_sb_valida_dep_inicial | Exito | 0 | Continua hacia validaciones de codigo |
| CTR-12 | cob_sbancario..sp_sb_valida_dep_inicial | Error de negocio | !=0 | @o_consulta=0 y retorno error |
| CTR-13 | cob_sbancario..sp_sb_valida_dep_inicial | Error tecnico | @@error | Corta flujo |
| CTR-14 | cob_sbancario..sp_sb_valida_dep_inicial | OUTs en NULL | n/a | No aplica |
| CTR-15 | cob_sbancario..sp_sb_valida_dep_inicial | Integridad pasantes | n/a | Monto en USD debe coincidir |
| CTR-16 | cob_cuentas..sp_val_ctas_rotativas | Exito | 0 | Continua flujo normal |
| CTR-17 | cob_cuentas..sp_val_ctas_rotativas | Error de negocio | !=0 | Emite sp_cerror si aplica y retorna |
| CTR-18 | cob_cuentas..sp_val_ctas_rotativas | Error tecnico | @@error | Corta flujo |
| CTR-19 | cob_cuentas..sp_val_ctas_rotativas | OUTs en NULL | n/a | No aplica |
| CTR-20 | cob_cuentas..sp_val_ctas_rotativas | Integridad pasantes | n/a | Debe usar @i_cta,@t_trn originales |
| CTR-21 | db_biz_admempresa..sp_con_parametroconf | Exito | @w_permite='S' | Permite deposito normal |
| CTR-22 | db_biz_admempresa..sp_con_parametroconf | Error de negocio | @w_permite='N' | Rechaza con 999999 |
| CTR-23 | db_biz_admempresa..sp_con_parametroconf | Error tecnico | @@error | Corta flujo |
| CTR-24 | db_biz_admempresa..sp_con_parametroconf | OUTs en NULL | NULL | Tratar como no permitido |
| CTR-25 | db_biz_admempresa..sp_con_parametroconf | Integridad pasantes | n/a | empresa/producto/servicio consistentes |
| CTR-26 | cob_cuentas..sp_convierte_valor | Exito | 0 | Ajusta montos/moneda interna |
| CTR-27 | cob_cuentas..sp_convierte_valor | Error de negocio | !=0 | Error 111111 |
| CTR-28 | cob_cuentas..sp_convierte_valor | Error tecnico | @@error | Corta flujo |
| CTR-29 | cob_cuentas..sp_convierte_valor | OUTs en NULL | 0 con OUT nulos | Evitar usar montos nulos |
| CTR-30 | cob_cuentas..sp_convierte_valor | Integridad pasantes | n/a | Preserva @i_efe/@i_loc origen caja |
| CTR-31 | cob_cuentas..sp_cta_origen | Exito | 0 | Define @w_tipo L/R |
| CTR-32 | cob_cuentas..sp_cta_origen | Error de negocio | !=0 | Retorno inmediato |
| CTR-33 | cob_cuentas..sp_cta_origen | Error tecnico | @@error | Corta flujo |
| CTR-34 | cob_cuentas..sp_cta_origen | OUTs en NULL | @w_tipo null | Riesgo de enrutamiento invalido |
| CTR-35 | cob_cuentas..sp_cta_origen | Integridad pasantes | n/a | Debe recibir cuenta y oficina correctas |
| CTR-36 | cob_cuentas..sp_cons_automatica_rc | Exito | 0 | Actualiza estatus consulta P/X |
| CTR-37 | cob_cuentas..sp_cons_automatica_rc | Error de negocio | !=0 | Emite error y retorna |
| CTR-38 | cob_cuentas..sp_cons_automatica_rc | Error tecnico | @@error | No debe perder trazabilidad |
| CTR-39 | cob_cuentas..sp_cons_automatica_rc | OUTs en NULL | status null | Mantener control de consulta |
| CTR-40 | cob_cuentas..sp_cons_automatica_rc | Integridad pasantes | n/a | @i_ssn,@i_codigo,@i_empresa intactos |
| CTR-41 | cobis..sp_verificacion_deposito_rc | Exito | 0 | Continua a transaccion local/remota |
| CTR-42 | cobis..sp_verificacion_deposito_rc | Error de negocio | !=0 | @o_consulta=0 y return |
| CTR-43 | cobis..sp_verificacion_deposito_rc | Error tecnico | @@error | Corta flujo |
| CTR-44 | cobis..sp_verificacion_deposito_rc | OUTs en NULL | 0 con cupo nulo | Riesgo en validacion cupo CNB |
| CTR-45 | cobis..sp_verificacion_deposito_rc | Integridad pasantes | n/a | Montos y canal deben ser consistentes |
| CTR-46 | cob_cuentas..sp_tr_depo2_local_remoto_rc | Exito | 0 | Propaga saldos/nombre/impuesto/neto |
| CTR-47 | cob_cuentas..sp_tr_depo2_local_remoto_rc | Error de negocio | 1 o !=0 | Reversa estado de consulta cuando aplica |
| CTR-48 | cob_cuentas..sp_tr_depo2_local_remoto_rc | Error tecnico | @@error | Retorno inmediato |
| CTR-49 | cob_cuentas..sp_tr_depo2_local_remoto_rc | OUTs en NULL | 0 con OUTs nulos | No corromper salidas del padre |
| CTR-50 | cob_cuentas..sp_tr_depo2_local_remoto_rc | Integridad pasantes | n/a | Parametros de canal/identificacion conservados |

--- TABLAS ACCEDIDAS ---
| # | tabla | operacion | lineas | es_catalogo |
|---|-------|-----------|--------|-------------|
| 1 | cobis..cl_parametro | R | 330,1014,1019 | SI |
| 2 | cob_cuentas..cc_tran_monet | R | 340 | NO |
| 3 | cobis..cl_catalogo | R | 385,416,530,760,777,884 | SI |
| 4 | cobis..cl_tabla | R | 385,416,532,744,884 | SI |
| 5 | cc_ctacte / cob_cuentas..cc_ctacte | RW | 490,614 | NO |
| 6 | cob_cuentas..cc_ctabloqueada | R | 522 | NO |
| 7 | cobis..cl_det_producto | W | 631 | NO |
| 8 | cob_cuentas..cc_his_cierre | W | 660 | NO |
| 9 | cob_cuentas..cc_tscierre_cta | W | 682 | NO |
| 10 | cob_cuentas..cc_codigo_afecta_bce | R | 753,794 | NO |
| 11 | db_biz_admempresa..ba_tabla | R | 837,847 | SI |
| 12 | db_biz_admempresa..ba_catalogo | R | 838,848 | SI |
| 13 | cob_pagos..pg_person_empresa | R | 879 | NO |
| 14 | cc_tran_monet | R | 1376 | NO |

--- VALORES HARDCODED ---
| id | valor | tipo | linea | participa_en | regla_asociada |
|----|-------|------|-------|--------------|----------------|
| HC-01 | 'CNB' | CADENA | 322 | canal permitido especial | RN-01 |
| HC-02 | 'cnb001' | CADENA | 322 | usuario exceptuado CNB | RN-01 |
| HC-03 | 708153 | CODIGO_RETORNO | 333 | parametro ALCNB inexistente | RN-02 |
| HC-04 | 300003178 | CODIGO_RETORNO | 336 | canal CNB inactivo | RN-03 |
| HC-05 | 130028 | CODIGO_RETORNO | 354 | transaccion duplicada CNB | RN-04 |
| HC-06 | 'V' | ESTADO | 389 | catalogos activos | RN-05 |
| HC-07 | 31004 | CODIGO_RETORNO | 504 | cuenta no existe | RN-06 |
| HC-08 | 'T' | ESTADO | 508 | estado no permite deposito | RN-07 |
| HC-09 | 128145 | CODIGO_RETORNO | 517 | estado de cuenta restringido | RN-07 |
| HC-10 | 'ATM' | CADENA | 556 | canal ATM | RN-08 |
| HC-11 | 17 | NUMERICO | 556 | moneda euro restringida ATM | RN-08 |
| HC-12 | 300003340 | CODIGO_RETORNO | 568 | rechazo ATM-euro | RN-08 |
| HC-13 | 'D' | ESTADO | 579 | estado deposito inicial | RN-09 |
| HC-14 | '25' | CODIGO | 610 | causa cierre SBS | RN-10 |
| HC-15 | 'Q' | ESTADO | 615 | estado cuenta cancelada | RN-10 |
| HC-16 | 3830 | TRN | 685 | transaccion cancelacion cuenta | RN-10 |
| HC-17 | 30018 | CODIGO_RETORNO | 716 | novedad SBS | RN-11 |
| HC-18 | 999999 | CODIGO_RETORNO | 770 | codigo/origen invalido | RN-12 |
| HC-19 | '6','21' | CODIGO | 783 | origenes con validacion reforzada | RN-12 |
| HC-20 | 111111 | CODIGO_RETORNO | 921 | error conversion moneda | RN-13 |
| HC-21 | 'VEN' | CADENA | 940 | canal ventanilla | RN-14 |
| HC-22 | 311819 | CODIGO_RETORNO | 1041 | monto fuera de umbral | RN-15 |
| HC-23 | 39007 | CODIGO_RETORNO | 1156 | cupo CNB excedido | RN-16 |
| HC-24 | 3040,3288,3553,3289,4435 | LISTA_TRN | 1189 | transacciones con tratamiento factura/identificacion | RN-17 |

--- REGLAS DE NEGOCIO ---
| id | descripcion_funcional | rn_tipo | condicion_origen | lineas | ramas_asociadas |
|----|----------------------|---------|------------------|--------|-----------------|
| RN-01 | Solo canal CNB distinto de usuario tecnico ejecuta validaciones especiales de canal | NEGOCIO | IF @i_canal='CNB' and @s_user!='cnb001' | 322 | RAMA-001 |
| RN-02 | Si no existe parametro ALCNB se rechaza operacion | CONTROL_TECNICO | IF @@rowcount=0 | 332-333 | RAMA-002 |
| RN-03 | Si canal CNB no esta activo (`A`) se rechaza | NEGOCIO | IF @v_estado_canal!='A' | 335-336 | RAMA-003 |
| RN-04 | No se permiten correcciones duplicadas CNB en misma fecha | NEGOCIO | IF EXISTS cc_tran_monet | 338-354 | RAMA-004,RAMA-005 |
| RN-05 | Si no llega codigo, se deriva desde catalogo por canal | NEGOCIO | IF @i_codigo is null | 383-391 | RAMA-008 |
| RN-06 | Cuenta inexistente aborta operacion | NEGOCIO | IF @@rowcount=0 sobre cc_ctacte | 493-504 | RAMA-013 |
| RN-07 | Estado T de cuenta no permite depositos | NEGOCIO | IF @w_estado='T' | 508-517 | RAMA-015 |
| RN-08 | ATM no permite depositos en moneda 17 (euros) | NEGOCIO | IF @i_canal='ATM' and @i_mon=17 | 556-571 | RAMA-019 |
| RN-09 | Cuentas en estado D deben pasar verificacion SBS y deposito inicial | NEGOCIO | IF @w_estado='D' | 579-733 | RAMA-022,RAMA-030 |
| RN-10 | Titular/firmantes inhabilitados SBS implican cierre de cuenta y registro historico | REGULATORIO | IF @w_existe_inhab='S'... | 608-701 | RAMA-024 |
| RN-11 | Cuando se cierra por SBS, retorna novedad 30018 y mensaje controlado | REGULATORIO | RETURN 30018 tras commit | 702-716 | RAMA-029 |
| RN-12 | Validacion cruzada codigo de afectacion BCE vs origen de cuenta | NEGOCIO | IF EXISTS/NOT EXISTS en cc_codigo_afecta_bce | 753-806 | RAMA-032,RAMA-033,RAMA-035,RAMA-036 |
| RN-13 | Empresas de deposito especial no pueden usar transaccion normal | NEGOCIO | IF @w_permite='N' o catalogo cl_emp_depesp | 837-897 | RAMA-039,RAMA-040,RAMA-043 |
| RN-14 | Para canal VEN se obtiene oficina/producto y tipo local/remoto; no VEN fuerza local | NEGOCIO | IF @i_canal='VEN' ELSE | 940-984 | RAMA-047,RAMA-050 |
| RN-15 | Montos fuera de umbral max/min en moneda caja local se rechazan | NEGOCIO | IF max/min | 1011-1041 | RAMA-054,RAMA-055 |
| RN-16 | En CNB se valida cupo: utilizado + efectivo <= cupo cliente | NEGOCIO | IF @v_valida_cupo > @w_cupo_cli | 1143-1156 | RAMA-061,RAMA-062 |
| RN-17 | Trx 3040/3288/3553/3289/4435 ajustan factura con identificacion depositante | NEGOCIO | IF @t_trn in (...) | 1189-1200,1391-1394 | RAMA-067,RAMA-070,RAMA-077 |
| RN-18 | Si falla deposito local y hubo consulta automatica previa, se revierte estatus a X | NEGOCIO | IF @i_ssn is not null and retorno invalido | 1318-1351 | RAMA-071 |

--- VARIABLES DISCRIMINADORAS ---
| id | variable | origen_valor | valores_posibles | es_constante | ramas_que_discrimina |
|----|----------|--------------|------------------|--------------|----------------------|
| VD-01 | @i_canal | PARAMETRO | VEN,CNB,ATM,WAP,SAT,otros | NO | RAMA-001,006,019,047,058,061,063,068,071 |
| VD-02 | @v_estado_canal | BD:cobis..cl_parametro.pa_char | A,otros,NULL | NO | RAMA-003 |
| VD-03 | @t_corr | PARAMETRO | N,S | NO | RAMA-004,030,052,057 |
| VD-04 | @w_estado | BD:cc_ctacte.cc_estado | D,T,otros | NO | RAMA-015,022 |
| VD-05 | @w_tipo | BD:sp_cta_origen OUT / CONSTANTE_CONDICIONAL | L,R | CONDICIONAL | RAMA-051,066,074,076,081 |
| VD-06 | @i_aplcobis | PARAMETRO | S,N | NO | RAMA-014,017,020,029,038,056 |
| VD-07 | @w_origen_cta | BD:cc_ctacte.cc_origen | 6,21,otros | NO | RAMA-033,034,035 |
| VD-08 | @w_permite | CONSTANTE_CONDICIONAL + SP OUT | S,N | CONDICIONAL | RAMA-040 |
| VD-09 | @w_return | SP hijo retorno | 0,1,!=0 | NO | RAMA-012,023,031,037,044,048,049,060,064,072,078,079,080 |
| VD-10 | @v_valida_cupo | CALCULO (@w_utilizado + @i_efe) | <=cupo,>cupo | NO | RAMA-062 |
| VD-11 | @s_org | PARAMETRO | U,D,S,otros | NO | RAMA-011,065,075 |
| VD-12 | @t_trn | PARAMETRO | 3040,3288,3553,3289,4435,otros | NO | RAMA-067,070,077 |

Tabla de condiciones discriminadoras detalladas:

| VD ID | Variable | Expresion SQL Exacta (linea) | Rama TRUE / Accion | Rama FALSE / Accion |
|-------|----------|------------------------------|-------------------|-------------------|
| VD-01 | @i_canal | IF @i_canal = 'CNB' and @s_user != 'cnb001' (L322) | Activa bloque de validaciones CNB | Continua flujo general |
| VD-02 | @v_estado_canal | IF @v_estado_canal != 'A' (L335) | return 300003178 | Sigue proceso CNB |
| VD-03 | @t_corr | IF @t_corr = 'S' (L338) | Valida duplicidad correccion | Omite control de duplicidad |
| VD-04 | @w_estado | IF @w_estado = 'D' (L579) | Ejecuta control SBS y deposito inicial | No entra a bloque SBS |
| VD-05 | @w_tipo | IF @w_tipo = 'L' (L1184) | Ejecuta transaccion local | Evalua rama remota |
| VD-06 | @i_aplcobis | IF @i_aplcobis='S' (L540) | Emite sp_cerror antes de return | Retorna directo |
| VD-07 | @w_origen_cta | IF @w_origen_cta in ('6','21') (L783) | Exige codigo BCE asociado | Mantiene validacion base |
| VD-08 | @w_permite | IF @w_permite = 'N' (L863) | Rechaza deposito normal | Permite continuar |
| VD-09 | @w_return | IF @w_return <> 0 (L1168) | @o_consulta=0 y return | Continua a enrutamiento final |
| VD-10 | @v_valida_cupo | IF @v_valida_cupo > @w_cupo_cli (L1148) | Error 39007 | Mantiene flujo |
| VD-11 | @s_org | IF @s_org='U' or @s_org='D' (L1181) | Flujo de transaccion local/origen usuario | Deriva a submitido @s_org='S' |
| VD-12 | @t_trn | IF @t_trn in (...) (L1189) | Ajusta factura/identificacion | Mantiene factura original |

--- INVENTARIO DE COBERTURA ---
| elemento_id | tipo | tecnica_responsable | descripcion | prioridad |
|-------------|------|---------------------|-------------|-----------|
| COV-FUN-001 | REGLA_DECISION | FUN | Activacion/desactivacion de canal CNB por parametro ALCNB | ALTA |
| COV-FUN-002 | REGLA_DECISION | FUN | Deteccion de transaccion duplicada en correccion CNB | ALTA |
| COV-FUN-003 | REGLA_DECISION | FUN | Restriccion ATM para moneda 17 | MEDIA |
| COV-FUN-004 | REGLA_DECISION | FUN | Cierre regulatorio SBS por inhabilitacion titular/firma | ALTA |
| COV-FUN-005 | REGLA_DECISION | FUN | Validacion codigo BCE vs origen cuenta | ALTA |
| COV-FUN-006 | REGLA_DECISION | FUN | Rechazo deposito normal para cuentas de deposito especial | ALTA |
| COV-FUN-007 | REGLA_DECISION | FUN | Control de montos max/min en moneda local | MEDIA |
| COV-FUN-008 | REGLA_DECISION | FUN | Validacion de cupo para canal CNB (Ref54) | ALTA |
| COV-FUN-009 | REGLA_DECISION | FUN | Ajuste de factura por tipo de transaccion/canal | MEDIA |
| COV-FUN-010 | REGLA_DECISION | FUN | Reversion de estado consulta automatica ante falla de posting | MEDIA |
| COV-TEC-001 | RAMA | TEC | Manejo de @w_return != 0 en dependencias criticas | ALTA |
| COV-TEC-002 | RAMA | TEC | Ramas else de @i_aplcobis y errores directos | MEDIA |
| COV-TEC-003 | RAMA | TEC | Enrutamiento local/remoto por @w_tipo | ALTA |
| COV-TEC-004 | ERROR_GUESSING | TEC | Comparacion a null con operador `=` en @i_codigo | ALTA |
| COV-TEC-005 | RAMA | TEC | Manejo de codigos de retorno 30018/39007/311819/111111 | ALTA |
| COV-RES-001 | CONTRATO_LIBRERIA | RES | Contrato de sp_tr_depo2_local_remoto_rc (0/1/error) | ALTA |
| COV-RES-002 | CONTRATO_LIBRERIA | RES | Contrato de sp_verificacion_deposito_rc con OUTs de cupo | ALTA |
| COV-RES-003 | CONTRATO_LIBRERIA | RES | Contrato de sp_convierte_valor para conversion monetaria | MEDIA |
| COV-RES-004 | CONTRATO_LIBRERIA | RES | Contrato de sp_cons_automatica_rc (estatus P/X) | MEDIA |
| COV-RES-005 | FRONTERA_BVA | RES | Fronteras de monto efectivo/local y cupo CNB | ALTA |

elementos_totales_FUN: 10
elementos_totales_TEC: 5
elementos_totales_RES: 5
elementos_totales: 20

--- CALCULO DE CASOS ---
| Factor | Calculo | Resultado |
|--------|---------|-----------|
| F1a (Discriminadores EP) | 10 params DISCRIMINADOR x 2 clases promedio | 20 |
| F1b (Pasantes contrato) | 44 params PASANTE x 1 | 44 |
| F2 (Limites BVA) | 8 params con limite real x 3 | 24 |
| F3 (Ramas testeable=SI, excluyendo ya contadas en F1a) | 26 ramas x 2 | 52 |
| F4 (Codigos retorno) | 15 codigos distintos (708153,300003178,130028,31004,128145,031008,300003340,35001,105050,33010,033005,30018,111111,311819,39007) | 15 |
| F5 (Transaccionales locales) | 1 bloque | 1 |
| F6 (Contrato libreria) | 5 x 10 SPs LIBRERIA_NEGOCIO | 50 |
| **Casos Brutos** | suma | **206** |
| **Exclusiones** | ver tabla detallada | **-58** |
| **Casos Finales Estimados** | brutos - exclusiones | **148** |

--- EXCLUSIONES DETALLADAS ---
| Concepto excluido | Cantidad | Motivo |
|-------------------|----------|--------|
| Ramas cubiertas por discriminador de F1a | 24 | mismo eje de decision, no se recuenta |
| Validaciones tecnicas repetitivas @w_return <> 0 | 14 | efecto equivalente: return inmediato |
| Duplicidad de contratos utilitarios | 8 | dependencias UTILITARIO no agregan escenario funcional nuevo |
| Combinaciones transitivas de montos (max/min vs conversion) | 12 | cubiertas por BVA y reglas principales |

--- BLOQUES TRANSACCIONALES ---
| # | linea_begin | linea_commit | linea_rollback | alcance | condicion_rollback |
|---|-------------|--------------|----------------|---------|-------------------|
| 1 | 613 | 701 | n/a explicito | Cierre regulatorio SBS (update cc_ctacte, update cl_det_producto, inserts historicos) | rollback implicito por return ante @@error/@@rowcount anomalo antes de commit |

--- DIMENSIONES D1-D6 ---
| Dimension | Peso | Valor | Clasificacion | Justificacion |
|-----------|------|-------|---------------|---------------|
| D1: Volumen | 15% | 1289 LOC cuerpo / 929 efectivas | CRITICA | supera umbral >1200 LOC |
| D2: Estructuras | 20% | 81 ramas inventariadas | ALTA | alta densidad de IF/ELSE y validaciones encadenadas |
| D3: Dependencias | 15% | 14 tablas + 18 SPs hijos | ALTA | alta acoplacion transversal entre modulos |
| D4: Transaccional | 10% | 1 bloque local con multiples writes | MEDIA | transaccion unica pero de impacto alto |
| D5: Financiera | 15% | uso extensivo de money, cupos, conversion y posting contable | ALTA | logica financiera directa |
| D6: Negocio | 25% | 5 (Regulatorio=3, Impacto=1, Frecuencia=1) | CRITICA | contiene control SBS, canal CNB y operacion OLTP masiva |

Complejidad final: **CRITICA**
Justificacion de redundancias eliminadas: se aplico consolidacion 2a (rutas equivalentes por discriminador), 2b (efectos transitivos ya cubiertos) y 2c (contratos utilitarios sin variacion funcional).
